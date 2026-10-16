using System.Net;
using System.Net.Sockets;

namespace Yippy.UseCases.Sync;

/// <summary>Checks the sync server address the user types.</summary>
public static class SyncServerAddress
{
    /// <summary>
    /// Accepts https addresses, and http ones only on this computer or the local network (e.g. a test server in Docker),
    /// since the auth token would otherwise cross the internet unencrypted. Records are encrypted either way.
    /// </summary>
    /// <param name="error">Why the address isn't accepted, for the user.</param>
    public static bool TryParse(string? text, out Uri address, out string? error)
    {
        address = null!;
        var trimmed = text?.Trim() ?? string.Empty;
        if (trimmed.Length > 0 && !trimmed.Contains("://", StringComparison.Ordinal))
        {
            trimmed = "https://" + trimmed;
        }
        if (!Uri.TryCreate(trimmed, UriKind.Absolute, out var uri) || (uri.Scheme != Uri.UriSchemeHttps && uri.Scheme != Uri.UriSchemeHttp)
            || uri.Host.Length == 0)
        {
            error = "Enter the server's address, e.g. https://sync.example.com.";
            return false;
        }
        if (uri.Scheme == Uri.UriSchemeHttp && !IsLocal(uri))
        {
            error = "Use https for a server on the internet.";
            return false;
        }
        address = uri;
        error = null;
        return true;
    }

    private static bool IsLocal(Uri uri)
    {
        if (uri.IsLoopback || uri.Host.EndsWith(".local", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }
        if (!IPAddress.TryParse(uri.Host, out var ip) || ip.AddressFamily != AddressFamily.InterNetwork)
        {
            return false;
        }
        var b = ip.GetAddressBytes();
        return b[0] == 10 || (b[0] == 172 && b[1] is >= 16 and <= 31) || (b[0] == 192 && b[1] == 168);
    }
}
