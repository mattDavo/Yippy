namespace SyncServer.Domain;

/// <summary>The latest change of one record: its encrypted data, or null if it was deleted.</summary>
public sealed record Change(string Key, long Seq, byte[]? Data)
{
    public bool IsDeleted => Data is null;
}

/// <summary>One page of changes after a sequence number.</summary>
/// <param name="Cursor">The sequence number to ask from next.</param>
/// <param name="More">Whether more changes are waiting beyond this page.</param>
/// <param name="Reset">Deletions after the requested sequence number were forgotten; the client should start again from 0.</param>
public sealed record ChangePage(IReadOnlyList<Change> Changes, long Cursor, bool More, bool Reset)
{
    public static ChangePage Empty(long cursor) => new(Array.Empty<Change>(), cursor, false, false);
}
