using System.IO;
using System.Security.Cryptography;
using Yippy.Domain.Sync;
using Yippy.UseCases.Abstractions;
using Yippy.UseCases.Sync;

namespace Yippy.Platform.Windows.Sync;

/// <summary>Keeps the sync key in a file encrypted for the current Windows user (DPAPI).</summary>
public sealed class DpapiSyncKeyStore : ISyncKeyStore
{
    private static readonly byte[] Entropy = "clipsync-v1 key"u8.ToArray();

    private readonly string path;
    private readonly IAppLogger logger;

    public DpapiSyncKeyStore(string path, IAppLogger logger)
    {
        this.path = path;
        this.logger = logger;
    }

    public SyncKey? Load()
    {
        if (!File.Exists(path))
        {
            return null;
        }
        try
        {
            var bytes = ProtectedData.Unprotect(File.ReadAllBytes(path), Entropy, DataProtectionScope.CurrentUser);
            return SyncKey.FromBytes(bytes);
        }
        catch (Exception e) when (e is CryptographicException or IOException or UnauthorizedAccessException or ArgumentException)
        {
            logger.Error($"Couldn't read the sync key in {path}; sync needs setting up again.", e);
            return null;
        }
    }

    public void Save(SyncKey? key)
    {
        try
        {
            if (key is null)
            {
                File.Delete(path);
                return;
            }
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            File.WriteAllBytes(path, ProtectedData.Protect(key.ToBytes(), Entropy, DataProtectionScope.CurrentUser));
        }
        catch (Exception e) when (e is CryptographicException or IOException or UnauthorizedAccessException)
        {
            logger.Error($"Couldn't save the sync key to {path}.", e);
        }
    }
}
