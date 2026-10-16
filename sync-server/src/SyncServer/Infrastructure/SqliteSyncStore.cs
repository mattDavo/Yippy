using Microsoft.Data.Sqlite;
using SyncServer.Application;
using SyncServer.Domain;

namespace SyncServer.Infrastructure;

/// <summary>Keeps spaces and records in one SQLite file.</summary>
public sealed class SqliteSyncStore : ISyncStore
{
    private readonly string connectionString;

    // SQLite allows one writer at a time; queue writers here rather than have them fail with SQLITE_BUSY
    private readonly SemaphoreSlim writeLock = new(1, 1);

    public SqliteSyncStore(string path)
    {
        var directory = Path.GetDirectoryName(Path.GetFullPath(path));
        if (directory is not null)
        {
            Directory.CreateDirectory(directory);
        }
        connectionString = new SqliteConnectionStringBuilder { DataSource = path, Pooling = true }.ToString();
        using var connection = Open();
        Execute(connection, null, """
            PRAGMA journal_mode = WAL;
            CREATE TABLE IF NOT EXISTS spaces (
                id TEXT PRIMARY KEY,
                token_hash BLOB NOT NULL,
                last_seq INTEGER NOT NULL DEFAULT 0,
                forgotten_seq INTEGER NOT NULL DEFAULT 0,
                created_at INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS records (
                space_id TEXT NOT NULL,
                key TEXT NOT NULL,
                seq INTEGER NOT NULL,
                data BLOB,
                size INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                PRIMARY KEY (space_id, key)
            );
            CREATE INDEX IF NOT EXISTS records_by_seq ON records (space_id, seq);
            """);
    }

    public async Task<byte[]?> GetTokenHashAsync(SpaceId space, CancellationToken cancellationToken)
    {
        await using var connection = Open();
        await using var command = Command(connection, null, "SELECT token_hash FROM spaces WHERE id = $space", ("$space", space.Value));
        return await command.ExecuteScalarAsync(cancellationToken) as byte[];
    }

    public Task<byte[]> ClaimSpaceAsync(SpaceId space, byte[] tokenHash, DateTimeOffset now, CancellationToken cancellationToken)
    {
        return WriteAsync(async (connection, transaction) =>
        {
            Execute(connection, transaction,
                "INSERT OR IGNORE INTO spaces (id, token_hash, created_at) VALUES ($space, $hash, $now)",
                ("$space", space.Value), ("$hash", tokenHash), ("$now", now.ToUnixTimeMilliseconds()));
            await using var command = Command(connection, transaction, "SELECT token_hash FROM spaces WHERE id = $space", ("$space", space.Value));
            return (byte[])(await command.ExecuteScalarAsync(cancellationToken))!;
        }, cancellationToken);
    }

    public Task<long> PutAsync(SpaceId space, RecordKey key, byte[] data, DateTimeOffset now, CancellationToken cancellationToken)
    {
        return WriteAsync((connection, transaction) =>
        {
            var seq = NextSeq(connection, transaction, space);
            Upsert(connection, transaction, space, key.Value, seq, data, now);
            return Task.FromResult(seq);
        }, cancellationToken);
    }

    public Task<long> DeleteAsync(SpaceId space, RecordKey key, DateTimeOffset now, CancellationToken cancellationToken)
    {
        return WriteAsync((connection, transaction) =>
        {
            var seq = NextSeq(connection, transaction, space);
            Upsert(connection, transaction, space, key.Value, seq, null, now);
            return Task.FromResult(seq);
        }, cancellationToken);
    }

    public Task<long> ClearAsync(SpaceId space, RecordKind kind, DateTimeOffset now, CancellationToken cancellationToken)
    {
        return WriteAsync(async (connection, transaction) =>
        {
            var keys = new List<string>();
            await using (var command = Command(connection, transaction,
                "SELECT key FROM records WHERE space_id = $space AND key LIKE $prefix AND data IS NOT NULL ORDER BY seq",
                ("$space", space.Value), ("$prefix", kind.Prefix() + "%")))
            await using (var reader = await command.ExecuteReaderAsync(cancellationToken))
            {
                while (await reader.ReadAsync(cancellationToken))
                {
                    keys.Add(reader.GetString(0));
                }
            }
            // Every deletion gets its own sequence number, so a page boundary can't fall in the middle of a shared one
            foreach (var key in keys)
            {
                Upsert(connection, transaction, space, key, NextSeq(connection, transaction, space), null, now);
            }
            return LastSeq(connection, transaction, space);
        }, cancellationToken);
    }

    public async Task<ChangePage> GetChangesAsync(SpaceId space, long since, int maxCount, long maxBytes, CancellationToken cancellationToken)
    {
        await using var connection = Open();
        await using var transaction = (SqliteTransaction)await connection.BeginTransactionAsync(cancellationToken);
        long lastSeq;
        long forgottenSeq;
        await using (var command = Command(connection, transaction,
            "SELECT last_seq, forgotten_seq FROM spaces WHERE id = $space", ("$space", space.Value)))
        await using (var reader = await command.ExecuteReaderAsync(cancellationToken))
        {
            if (!await reader.ReadAsync(cancellationToken))
            {
                return since == 0 ? ChangePage.Empty(0) : new ChangePage(Array.Empty<Change>(), 0, false, true);
            }
            lastSeq = reader.GetInt64(0);
            forgottenSeq = reader.GetInt64(1);
        }
        // The client missed forgotten deletions, or knows of changes this space never had (it was deleted and made again)
        if (since > 0 && (since < forgottenSeq || since > lastSeq))
        {
            return new ChangePage(Array.Empty<Change>(), 0, false, true);
        }

        var changes = new List<Change>();
        long bytes = 0;
        var more = false;
        await using (var command = Command(connection, transaction,
            "SELECT key, seq, data FROM records WHERE space_id = $space AND seq > $since ORDER BY seq LIMIT $limit",
            ("$space", space.Value), ("$since", since), ("$limit", maxCount + 1)))
        await using (var reader = await command.ExecuteReaderAsync(cancellationToken))
        {
            while (await reader.ReadAsync(cancellationToken))
            {
                var data = reader.IsDBNull(2) ? null : (byte[])reader.GetValue(2);
                var size = data?.Length ?? 0;
                if (changes.Count == maxCount || (changes.Count > 0 && bytes + size > maxBytes))
                {
                    more = true;
                    break;
                }
                changes.Add(new Change(reader.GetString(0), reader.GetInt64(1), data));
                bytes += size;
            }
        }
        var cursor = more ? changes[^1].Seq : lastSeq;
        return new ChangePage(changes, cursor, more, false);
    }

    public Task DeleteSpaceAsync(SpaceId space, CancellationToken cancellationToken)
    {
        return WriteAsync((connection, transaction) =>
        {
            Execute(connection, transaction, "DELETE FROM records WHERE space_id = $space", ("$space", space.Value));
            Execute(connection, transaction, "DELETE FROM spaces WHERE id = $space", ("$space", space.Value));
            return Task.FromResult(0);
        }, cancellationToken);
    }

    public Task EnforceQuotaAsync(SpaceId space, long maxBytes, CancellationToken cancellationToken)
    {
        return WriteAsync(async (connection, transaction) =>
        {
            await using var total = Command(connection, transaction,
                "SELECT COALESCE(SUM(size), 0) FROM records WHERE space_id = $space", ("$space", space.Value));
            var bytes = (long)(await total.ExecuteScalarAsync(cancellationToken))!;
            if (bytes <= maxBytes)
            {
                return 0;
            }
            var dropped = new List<(string Key, long Size)>();
            await using (var command = Command(connection, transaction,
                "SELECT key, size FROM records WHERE space_id = $space AND key LIKE 'h/%' AND data IS NOT NULL ORDER BY updated_at, seq",
                ("$space", space.Value)))
            await using (var reader = await command.ExecuteReaderAsync(cancellationToken))
            {
                while (bytes > maxBytes && await reader.ReadAsync(cancellationToken))
                {
                    dropped.Add((reader.GetString(0), reader.GetInt64(1)));
                    bytes -= reader.GetInt64(1);
                }
            }
            foreach (var (key, _) in dropped)
            {
                Execute(connection, transaction, "DELETE FROM records WHERE space_id = $space AND key = $key",
                    ("$space", space.Value), ("$key", key));
            }
            return dropped.Count;
        }, cancellationToken);
    }

    public Task ApplyRetentionAsync(DateTimeOffset historyBefore, DateTimeOffset deletionsBefore, CancellationToken cancellationToken)
    {
        return WriteAsync((connection, transaction) =>
        {
            Execute(connection, transaction,
                "DELETE FROM records WHERE key LIKE 'h/%' AND data IS NOT NULL AND updated_at < $before",
                ("$before", historyBefore.ToUnixTimeMilliseconds()));
            // Clients asking from before a forgotten deletion are told to start again (ChangePage.Reset)
            Execute(connection, transaction, """
                UPDATE spaces SET forgotten_seq = MAX(forgotten_seq, COALESCE(
                    (SELECT MAX(seq) FROM records r WHERE r.space_id = spaces.id AND r.data IS NULL AND r.updated_at < $before), 0))
                """,
                ("$before", deletionsBefore.ToUnixTimeMilliseconds()));
            Execute(connection, transaction, "DELETE FROM records WHERE data IS NULL AND updated_at < $before",
                ("$before", deletionsBefore.ToUnixTimeMilliseconds()));
            return Task.FromResult(0);
        }, cancellationToken);
    }

    private SqliteConnection Open()
    {
        var connection = new SqliteConnection(connectionString);
        connection.Open();
        Execute(connection, null, "PRAGMA busy_timeout = 5000;");
        return connection;
    }

    private async Task<T> WriteAsync<T>(Func<SqliteConnection, SqliteTransaction, Task<T>> write, CancellationToken cancellationToken)
    {
        await writeLock.WaitAsync(cancellationToken);
        try
        {
            await using var connection = Open();
            await using var transaction = connection.BeginTransaction(deferred: false);
            var result = await write(connection, transaction);
            await transaction.CommitAsync(cancellationToken);
            return result;
        }
        finally
        {
            writeLock.Release();
        }
    }

    private static long NextSeq(SqliteConnection connection, SqliteTransaction transaction, SpaceId space)
    {
        using var command = Command(connection, transaction,
            "UPDATE spaces SET last_seq = last_seq + 1 WHERE id = $space RETURNING last_seq", ("$space", space.Value));
        return (long)(command.ExecuteScalar() ?? throw new InvalidOperationException($"Space {space} doesn't exist."));
    }

    private static long LastSeq(SqliteConnection connection, SqliteTransaction transaction, SpaceId space)
    {
        using var command = Command(connection, transaction, "SELECT last_seq FROM spaces WHERE id = $space", ("$space", space.Value));
        return (long)command.ExecuteScalar()!;
    }

    private static void Upsert(SqliteConnection connection, SqliteTransaction transaction, SpaceId space, string key, long seq, byte[]? data, DateTimeOffset now)
    {
        Execute(connection, transaction, """
            INSERT INTO records (space_id, key, seq, data, size, updated_at) VALUES ($space, $key, $seq, $data, $size, $now)
            ON CONFLICT (space_id, key) DO UPDATE SET seq = excluded.seq, data = excluded.data, size = excluded.size, updated_at = excluded.updated_at
            """,
            ("$space", space.Value), ("$key", key), ("$seq", seq), ("$data", (object?)data ?? DBNull.Value),
            ("$size", (long)(data?.Length ?? 0)), ("$now", now.ToUnixTimeMilliseconds()));
    }

    private static void Execute(SqliteConnection connection, SqliteTransaction? transaction, string sql, params (string Name, object Value)[] parameters)
    {
        using var command = Command(connection, transaction, sql, parameters);
        command.ExecuteNonQuery();
    }

    private static SqliteCommand Command(SqliteConnection connection, SqliteTransaction? transaction, string sql, params (string Name, object Value)[] parameters)
    {
        var command = connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = sql;
        foreach (var (name, value) in parameters)
        {
            command.Parameters.AddWithValue(name, value);
        }
        return command;
    }
}
