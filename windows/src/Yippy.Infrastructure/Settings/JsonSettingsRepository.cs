using System.Text.Json;
using Yippy.Domain.Settings;
using Yippy.Infrastructure.Storage;
using Yippy.UseCases.Abstractions;

namespace Yippy.Infrastructure.Settings;

/// <summary>Keeps the settings in a JSON file. Values missing from the file (saved by an older version) take their defaults.</summary>
public sealed class JsonSettingsRepository : ISettingsRepository
{
    private readonly string path;
    private readonly IAppLogger logger;

    public JsonSettingsRepository(string path, IAppLogger logger)
    {
        this.path = path;
        this.logger = logger;
    }

    public AppSettings? Load()
    {
        if (!File.Exists(path))
        {
            return null;
        }
        try
        {
            using var stream = File.OpenRead(path);
            return JsonSerializer.Deserialize<AppSettings>(stream, JsonDefaults.Options) ?? AppSettings.Default;
        }
        catch (Exception e) when (e is JsonException or IOException or UnauthorizedAccessException or NotSupportedException)
        {
            // Keep the unreadable file for a look later, and start again from the defaults
            logger.Error($"Couldn't read the settings in {path}; using the defaults.", e);
            TryMove(path, path + ".unreadable");
            return AppSettings.Default;
        }
    }

    public void Save(AppSettings settings)
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            JsonDefaults.WriteAtomically(path, settings, typeof(AppSettings));
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException)
        {
            logger.Error($"Couldn't save the settings to {path}.", e);
        }
    }

    private static void TryMove(string from, string to)
    {
        try
        {
            File.Move(from, to, overwrite: true);
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException)
        {
            // Nothing else to do; the defaults are used either way
        }
    }
}
