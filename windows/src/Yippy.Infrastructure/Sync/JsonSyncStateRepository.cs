using System.Text.Json;
using Yippy.Infrastructure.Storage;
using Yippy.UseCases.Abstractions;
using Yippy.UseCases.Sync;

namespace Yippy.Infrastructure.Sync;

/// <summary>Keeps the sync state in a JSON file. An unreadable file starts sync again from the beginning.</summary>
public sealed class JsonSyncStateRepository : ISyncStateRepository
{
    private readonly string path;
    private readonly IAppLogger logger;

    public JsonSyncStateRepository(string path, IAppLogger logger)
    {
        this.path = path;
        this.logger = logger;
    }

    public SyncState Load()
    {
        if (!File.Exists(path))
        {
            return SyncState.Empty;
        }
        try
        {
            using var stream = File.OpenRead(path);
            return JsonSerializer.Deserialize<SyncState>(stream, JsonDefaults.Options) ?? SyncState.Empty;
        }
        catch (Exception e) when (e is JsonException or IOException or UnauthorizedAccessException or NotSupportedException)
        {
            logger.Error($"Couldn't read the sync state in {path}; syncing from the beginning.", e);
            return SyncState.Empty;
        }
    }

    public void Save(SyncState state)
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            JsonDefaults.WriteAtomically(path, state, typeof(SyncState));
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException)
        {
            logger.Error($"Couldn't save the sync state to {path}.", e);
        }
    }
}
