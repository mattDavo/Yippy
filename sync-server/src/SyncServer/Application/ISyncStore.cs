using SyncServer.Domain;

namespace SyncServer.Application;

/// <summary>Where spaces and their records are kept (Repository pattern). Every method is atomic.</summary>
public interface ISyncStore
{
    /// <returns>The hash of the space's auth token, or null if the space doesn't exist.</returns>
    Task<byte[]?> GetTokenHashAsync(SpaceId space, CancellationToken cancellationToken);

    /// <summary>Creates the space with this token hash, unless it already exists.</summary>
    /// <returns>The space's token hash: this one if the space was created, else the one it already had.</returns>
    Task<byte[]> ClaimSpaceAsync(SpaceId space, byte[] tokenHash, DateTimeOffset now, CancellationToken cancellationToken);

    /// <returns>The change's sequence number.</returns>
    Task<long> PutAsync(SpaceId space, RecordKey key, byte[] data, DateTimeOffset now, CancellationToken cancellationToken);

    /// <summary>Marks the record deleted, so clients that sync later learn of it.</summary>
    /// <returns>The change's sequence number.</returns>
    Task<long> DeleteAsync(SpaceId space, RecordKey key, DateTimeOffset now, CancellationToken cancellationToken);

    /// <summary>Marks every record of the kind deleted.</summary>
    /// <returns>The space's latest sequence number.</returns>
    Task<long> ClearAsync(SpaceId space, RecordKind kind, DateTimeOffset now, CancellationToken cancellationToken);

    /// <summary>
    /// The changes after <paramref name="since"/>, oldest first: at most <paramref name="maxCount"/>, and stopping once
    /// <paramref name="maxBytes"/> of data is reached (but always at least one).
    /// </summary>
    Task<ChangePage> GetChangesAsync(SpaceId space, long since, int maxCount, long maxBytes, CancellationToken cancellationToken);

    Task DeleteSpaceAsync(SpaceId space, CancellationToken cancellationToken);

    /// <summary>Drops the space's oldest history records, without remembering a deletion, until it fits.</summary>
    Task EnforceQuotaAsync(SpaceId space, long maxBytes, CancellationToken cancellationToken);

    /// <summary>
    /// Drops history records last written before <paramref name="historyBefore"/> and forgets deletions made before
    /// <paramref name="deletionsBefore"/>, in every space.
    /// </summary>
    Task ApplyRetentionAsync(DateTimeOffset historyBefore, DateTimeOffset deletionsBefore, CancellationToken cancellationToken);
}
