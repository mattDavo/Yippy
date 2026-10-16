namespace SyncServer.Application;

/// <summary>The server's settings, read from environment variables (see README.md).</summary>
public sealed record ServerOptions
{
    /// <summary>The SQLite database file.</summary>
    public string DatabasePath { get; init; } = "data/sync.db";

    /// <summary>If set, every request but the health check needs it in the <c>X-Access-Key</c> header.</summary>
    public string? AccessKey { get; init; }

    public long MaxRecordBytes { get; init; } = 25L * 1024 * 1024;

    public long SpaceQuotaBytes { get; init; } = 512L * 1024 * 1024;

    /// <summary>How long history records are kept. Favourites are kept until deleted.</summary>
    public TimeSpan HistoryRetention { get; init; } = TimeSpan.FromDays(30);

    /// <summary>How long deletions are remembered for clients that are offline.</summary>
    public TimeSpan DeletionRetention { get; init; } = TimeSpan.FromDays(30);

    /// <summary>The longest a request for changes waits for one.</summary>
    public TimeSpan MaxWait { get; init; } = TimeSpan.FromSeconds(60);

    public int MaxChangesPerPage { get; init; } = 200;

    public long MaxPageBytes { get; init; } = 8L * 1024 * 1024;

    public static ServerOptions FromEnvironment(Func<string, string?> read)
    {
        var defaults = new ServerOptions();
        return new ServerOptions
        {
            DatabasePath = read("SYNC_DB_PATH") is { Length: > 0 } path ? path : defaults.DatabasePath,
            AccessKey = read("SYNC_ACCESS_KEY") is { Length: > 0 } key ? key : null,
            MaxRecordBytes = Megabytes(read("SYNC_MAX_RECORD_MB")) ?? defaults.MaxRecordBytes,
            SpaceQuotaBytes = Megabytes(read("SYNC_SPACE_QUOTA_MB")) ?? defaults.SpaceQuotaBytes,
            HistoryRetention = Days(read("SYNC_HISTORY_DAYS")) ?? defaults.HistoryRetention,
            DeletionRetention = Days(read("SYNC_DELETION_DAYS")) ?? defaults.DeletionRetention,
        };
    }

    private static long? Megabytes(string? text) => long.TryParse(text, out var mb) && mb > 0 ? mb * 1024 * 1024 : null;

    private static TimeSpan? Days(string? text) => int.TryParse(text, out var days) && days > 0 ? TimeSpan.FromDays(days) : null;
}
