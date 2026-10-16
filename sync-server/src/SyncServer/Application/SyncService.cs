using System.Security.Cryptography;
using System.Text;
using SyncServer.Domain;

namespace SyncServer.Application;

/// <summary>
/// The server's use cases: checking a client may use a space, storing and deleting its records, and handing out changes,
/// waiting for one if there are none yet (long polling).
/// </summary>
public sealed class SyncService
{
    private readonly ISyncStore store;
    private readonly ChangeSignal signal;
    private readonly ServerOptions options;
    private readonly TimeProvider time;

    public SyncService(ISyncStore store, ChangeSignal signal, ServerOptions options, TimeProvider time)
    {
        this.store = store;
        this.signal = signal;
        this.options = options;
        this.time = time;
    }

    public async Task<long> PutAsync(SpaceId space, string token, RecordKey key, byte[] data, CancellationToken cancellationToken)
    {
        if (data.Length > options.MaxRecordBytes)
        {
            throw new SyncException(SyncError.TooLarge, $"Records can be at most {options.MaxRecordBytes} bytes.");
        }
        await AuthorizeWriteAsync(space, token, cancellationToken);
        var seq = await store.PutAsync(space, key, data, time.GetUtcNow(), cancellationToken);
        await store.EnforceQuotaAsync(space, options.SpaceQuotaBytes, cancellationToken);
        signal.Notify(space);
        return seq;
    }

    public async Task<long> DeleteAsync(SpaceId space, string token, RecordKey key, CancellationToken cancellationToken)
    {
        await AuthorizeWriteAsync(space, token, cancellationToken);
        var seq = await store.DeleteAsync(space, key, time.GetUtcNow(), cancellationToken);
        signal.Notify(space);
        return seq;
    }

    public async Task<long> ClearAsync(SpaceId space, string token, RecordKind kind, CancellationToken cancellationToken)
    {
        await AuthorizeWriteAsync(space, token, cancellationToken);
        var seq = await store.ClearAsync(space, kind, time.GetUtcNow(), cancellationToken);
        signal.Notify(space);
        return seq;
    }

    public async Task DeleteSpaceAsync(SpaceId space, string token, CancellationToken cancellationToken)
    {
        if (await AuthorizeReadAsync(space, token, cancellationToken))
        {
            await store.DeleteSpaceAsync(space, cancellationToken);
            signal.Notify(space);
        }
    }

    /// <summary>The changes after <paramref name="since"/>, waiting up to <paramref name="wait"/> if there are none yet.</summary>
    public async Task<ChangePage> GetChangesAsync(SpaceId space, string token, long since, TimeSpan wait, CancellationToken cancellationToken)
    {
        if (!await AuthorizeReadAsync(space, token, cancellationToken))
        {
            // Nothing has been written yet (the first write creates the space), or the space was deleted
            return since == 0 ? ChangePage.Empty(0) : new ChangePage(Array.Empty<Change>(), 0, false, true);
        }
        if (wait > options.MaxWait)
        {
            wait = options.MaxWait;
        }
        var next = signal.NextChange(space);
        var page = await store.GetChangesAsync(space, since, options.MaxChangesPerPage, options.MaxPageBytes, cancellationToken);
        if (page.Changes.Count > 0 || page.Reset || wait <= TimeSpan.Zero)
        {
            return page;
        }
        try
        {
            await next.WaitAsync(wait, time, cancellationToken);
        }
        catch (TimeoutException)
        {
            return page;
        }
        return await store.GetChangesAsync(space, since, options.MaxChangesPerPage, options.MaxPageBytes, cancellationToken);
    }

    /// <summary>Checks the token, creating the space for it if this is the space's first write.</summary>
    private async Task AuthorizeWriteAsync(SpaceId space, string token, CancellationToken cancellationToken)
    {
        var hash = HashToken(token);
        var stored = await store.ClaimSpaceAsync(space, hash, time.GetUtcNow(), cancellationToken);
        if (!CryptographicOperations.FixedTimeEquals(stored, hash))
        {
            throw Unauthorized();
        }
    }

    /// <returns>Whether the space exists. Throws if it does and the token isn't its.</returns>
    private async Task<bool> AuthorizeReadAsync(SpaceId space, string token, CancellationToken cancellationToken)
    {
        var stored = await store.GetTokenHashAsync(space, cancellationToken);
        if (stored is null)
        {
            return false;
        }
        if (!CryptographicOperations.FixedTimeEquals(stored, HashToken(token)))
        {
            throw Unauthorized();
        }
        return true;
    }

    private static byte[] HashToken(string token) => SHA256.HashData(Encoding.UTF8.GetBytes(token));

    private static SyncException Unauthorized() => new(SyncError.Unauthorized, "This sync key doesn't match the space.");
}
