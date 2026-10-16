using Yippy.Domain.Sync;
using Yippy.UseCases.Sync;

namespace Yippy.Tests.Fakes;

/// <summary>
/// The sync server's behaviour in memory (sync-server/PROTOCOL.md): one space whose records keep their latest change.
/// Several devices can share it.
/// </summary>
public sealed class FakeSyncServer : ISyncServerFactory
{
    private readonly Dictionary<string, (long Seq, byte[]? Data)> records = new();
    private long lastSeq;

    public bool IsReachable { get; set; } = true;

    public int MaxRecordBytes { get; set; } = int.MaxValue;

    public IReadOnlyDictionary<string, (long Seq, byte[]? Data)> Records => records;

    public IEnumerable<string> LiveKeys => records.Where(r => r.Value.Data is not null).OrderBy(r => r.Value.Seq).Select(r => r.Key);

    public ISyncServer Create(SyncConnection connection) => new Connection(this);

    /// <summary>Drops a record without a deletion, as the server does to history when it runs out of space.</summary>
    public void Evict(string key) => records.Remove(key);

    private void Write(string key, byte[]? data)
    {
        Check();
        records[key] = (++lastSeq, data);
    }

    private void Check()
    {
        if (!IsReachable)
        {
            throw new SyncServerException(SyncServerError.Unreachable, "Can't reach the sync server.");
        }
    }

    private sealed class Connection : ISyncServer
    {
        private readonly FakeSyncServer server;

        public Connection(FakeSyncServer server) => this.server = server;

        public Task PutAsync(SyncRecordKey key, byte[] data, CancellationToken cancellationToken)
        {
            if (data.Length > server.MaxRecordBytes)
            {
                throw new SyncServerException(SyncServerError.Rejected, "Too large.");
            }
            server.Write(key.ToString(), data);
            return Task.CompletedTask;
        }

        public Task DeleteAsync(SyncRecordKey key, CancellationToken cancellationToken)
        {
            server.Write(key.ToString(), null);
            return Task.CompletedTask;
        }

        public Task ClearAsync(SyncRecordKind kind, CancellationToken cancellationToken)
        {
            var prefix = SyncRecordKey.PrefixOf(kind) + "/";
            foreach (var key in server.LiveKeys.Where(k => k.StartsWith(prefix, StringComparison.Ordinal)).ToList())
            {
                server.Write(key, null);
            }
            return Task.CompletedTask;
        }

        public Task<SyncChangePage> GetChangesAsync(long since, TimeSpan wait, CancellationToken cancellationToken)
        {
            server.Check();
            var changes = server.records
                .Where(r => r.Value.Seq > since)
                .OrderBy(r => r.Value.Seq)
                .Select(r => new SyncChange(r.Key, r.Value.Seq, r.Value.Data))
                .ToList();
            return Task.FromResult(new SyncChangePage(changes, server.lastSeq, false, false));
        }

        public Task DeleteSpaceAsync(CancellationToken cancellationToken)
        {
            server.Check();
            server.records.Clear();
            return Task.CompletedTask;
        }

        public void Dispose()
        {
        }
    }
}

public sealed class InMemorySyncStateRepository : ISyncStateRepository
{
    public SyncState Saved { get; private set; } = SyncState.Empty;

    public SyncState Load() => Saved;

    public void Save(SyncState state) => Saved = state;
}

public sealed class InMemorySyncKeyStore : ISyncKeyStore
{
    public InMemorySyncKeyStore(SyncKey? key = null) => Key = key;

    public SyncKey? Key { get; private set; }

    public SyncKey? Load() => Key;

    public void Save(SyncKey? key) => Key = key;
}

/// <summary>Pretends to convert images: a "DIB" is the PNG's bytes behind a marker byte.</summary>
public sealed class FakeImageCodec : IImageCodec
{
    public byte[]? DibToPng(byte[] dib) => dib.Length > 0 && dib[0] == 0xD1 ? dib[1..] : null;

    public byte[]? PngToDib(byte[] png) => new byte[] { 0xD1 }.Concat(png).ToArray();
}
