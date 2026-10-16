using System.Security.Cryptography;
using System.Text;

namespace Yippy.Domain.Sync;

/// <summary>The formats an item is synced in, the same on every platform (see sync-server/PROTOCOL.md).</summary>
public static class SyncFormats
{
    /// <summary>UTF-8 text.</summary>
    public const string Text = "text";

    public const string Rtf = "rtf";

    /// <summary>UTF-8 HTML, without Windows' offset header.</summary>
    public const string Html = "html";

    public const string Png = "png";

    public static readonly IReadOnlySet<string> All = new HashSet<string>(StringComparer.Ordinal) { Text, Rtf, Html, Png };
}

/// <summary>An item's content in the <see cref="SyncFormats"/>. Immutable.</summary>
public sealed class SyncContent
{
    private readonly SortedDictionary<string, byte[]> formats;

    public SyncContent(IEnumerable<KeyValuePair<string, byte[]>> formats)
    {
        this.formats = new SortedDictionary<string, byte[]>(StringComparer.Ordinal);
        foreach (var (name, data) in formats)
        {
            if (SyncFormats.All.Contains(name))
            {
                this.formats[name] = data;
            }
        }
    }

    public IReadOnlyDictionary<string, byte[]> Formats => formats;

    public bool IsEmpty => formats.Count == 0;

    public byte[]? Get(string format) => formats.TryGetValue(format, out var data) ? data : null;

    public string? Text => Get(SyncFormats.Text) is { } data ? Encoding.UTF8.GetString(data) : null;

    /// <summary>
    /// The content as hashed for its record id: each format in ordinal order of name, as the name's UTF-8 length
    /// (64-bit little-endian), the name, the data's length (64-bit little-endian) and the data.
    /// </summary>
    public byte[] CanonicalBytes()
    {
        using var stream = new MemoryStream();
        Span<byte> length = stackalloc byte[8];
        foreach (var (name, data) in formats)
        {
            var nameBytes = Encoding.UTF8.GetBytes(name);
            BitConverter.TryWriteBytes(length, (long)nameBytes.Length);
            stream.Write(length);
            stream.Write(nameBytes);
            BitConverter.TryWriteBytes(length, (long)data.Length);
            stream.Write(length);
            stream.Write(data);
        }
        return stream.ToArray();
    }
}

/// <summary>What a record holds; its kind is in its key.</summary>
public enum SyncRecordKind
{
    History,
    Favourite,
}

/// <summary>A record's key: <c>h/&lt;id&gt;</c> or <c>f/&lt;id&gt;</c>.</summary>
public sealed record SyncRecordKey(SyncRecordKind Kind, string Id)
{
    public static string PrefixOf(SyncRecordKind kind) => kind == SyncRecordKind.History ? "h" : "f";

    /// <summary>The key's id for this content: the first 16 bytes of HMAC-SHA256 under the key's id key, base64url.</summary>
    public static SyncRecordKey For(SyncRecordKind kind, SyncContent content, SyncKey key)
    {
        var mac = HMACSHA256.HashData(key.IdKey, content.CanonicalBytes());
        return new SyncRecordKey(kind, Base64Url.Encode(mac.AsSpan(0, 16)));
    }

    public static SyncRecordKey? TryParse(string text)
    {
        var slash = text.IndexOf('/');
        if (slash < 0)
        {
            return null;
        }
        var kind = text[..slash] switch
        {
            "h" => SyncRecordKind.History,
            "f" => (SyncRecordKind?)SyncRecordKind.Favourite,
            _ => null,
        };
        return kind is { } k && slash + 1 < text.Length ? new SyncRecordKey(k, text[(slash + 1)..]) : null;
    }

    public override string ToString() => PrefixOf(Kind) + "/" + Id;
}
