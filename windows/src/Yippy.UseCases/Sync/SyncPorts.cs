using Yippy.Domain.Sync;

namespace Yippy.UseCases.Sync;

// Ports for sync: the server, and where the sync state and key are kept.

/// <summary>Where and how to sync: the server's address, its access key if it has one, and the user's sync key.</summary>
public sealed record SyncConnection(Uri Server, string? AccessKey, SyncKey Key);

/// <summary>The latest change of one record; <see cref="Data"/> is null if it was deleted.</summary>
public sealed record SyncChange(string Key, long Seq, byte[]? Data);

/// <param name="Cursor">Where to ask from next.</param>
/// <param name="More">More changes are waiting; ask again straight away.</param>
/// <param name="Reset">The server can't answer from the given cursor; ask again from 0.</param>
public sealed record SyncChangePage(IReadOnlyList<SyncChange> Changes, long Cursor, bool More, bool Reset);

public enum SyncServerError
{
    /// <summary>The server can't be reached or answered with a server error. Worth retrying.</summary>
    Unreachable,

    /// <summary>The server needs an access key, or a different one.</summary>
    AccessKeyRefused,

    /// <summary>Another sync key already owns the space. Unlikely unless the server's data was mixed up.</summary>
    KeyRefused,

    /// <summary>The server refused the request, e.g. a record over its size limit. Retrying won't help.</summary>
    Rejected,
}

public sealed class SyncServerException : Exception
{
    public SyncServerException(SyncServerError error, string message, Exception? inner = null)
        : base(message, inner)
    {
        Error = error;
    }

    public SyncServerError Error { get; }
}

/// <summary>A space on the sync server (sync-server/PROTOCOL.md). Throws <see cref="SyncServerException"/>.</summary>
public interface ISyncServer : IDisposable
{
    Task PutAsync(SyncRecordKey key, byte[] data, CancellationToken cancellationToken);

    Task DeleteAsync(SyncRecordKey key, CancellationToken cancellationToken);

    /// <summary>Deletes every record of the kind.</summary>
    Task ClearAsync(SyncRecordKind kind, CancellationToken cancellationToken);

    /// <summary>The changes after <paramref name="since"/>, waiting up to <paramref name="wait"/> for one if there are none.</summary>
    Task<SyncChangePage> GetChangesAsync(long since, TimeSpan wait, CancellationToken cancellationToken);

    /// <summary>Deletes everything the space holds.</summary>
    Task DeleteSpaceAsync(CancellationToken cancellationToken);
}

/// <summary>Connects to sync servers (Abstract Factory), so the use cases don't know about HTTP.</summary>
public interface ISyncServerFactory
{
    ISyncServer Create(SyncConnection connection);
}

/// <summary>A change waiting to be sent: a record to write or delete, or a kind of record to clear.</summary>
/// <param name="ItemId">For <see cref="SyncOperation.Put"/>: the item whose current content is sent.</param>
public sealed record PendingSyncChange(SyncOperation Operation, SyncRecordKind Kind, string? RecordId = null, Guid? ItemId = null);

public enum SyncOperation
{
    Put,
    Delete,
    Clear,
}

/// <summary>What a device remembers about syncing between runs.</summary>
public sealed record SyncState
{
    /// <summary>The space the rest belongs to; a new sync key starts again.</summary>
    public string? SpaceId { get; init; }

    /// <summary>The server's sequence number this device has caught up to.</summary>
    public long Cursor { get; init; }

    /// <summary>Whether the favourites and recent history that were here before sync was turned on have been sent.</summary>
    public bool SentExistingItems { get; init; }

    /// <summary>The record id of each local item, so an item keeps its id however its content is converted.</summary>
    public IReadOnlyDictionary<Guid, string> RecordIds { get; init; } = new Dictionary<Guid, string>();

    public IReadOnlyList<PendingSyncChange> Pending { get; init; } = Array.Empty<PendingSyncChange>();

    public static SyncState Empty { get; } = new();
}

public interface ISyncStateRepository
{
    SyncState Load();

    void Save(SyncState state);
}

/// <summary>Keeps the sync key, protected for the current user where the platform can.</summary>
public interface ISyncKeyStore
{
    SyncKey? Load();

    /// <param name="key">Null forgets the key.</param>
    void Save(SyncKey? key);
}

/// <summary>Converts images between the clipboard's bitmap format and PNG.</summary>
public interface IImageCodec
{
    /// <param name="dib">A <c>CF_DIB</c> or <c>CF_DIBV5</c>.</param>
    /// <returns>The image as PNG, or null if it can't be read.</returns>
    byte[]? DibToPng(byte[] dib);

    /// <returns>The image as a <c>CF_DIB</c>, or null if it can't be read.</returns>
    byte[]? PngToDib(byte[] png);
}
