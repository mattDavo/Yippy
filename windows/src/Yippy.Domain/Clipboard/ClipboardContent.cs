using System.Security.Cryptography;
using System.Text;
using Yippy.Domain.Text;

namespace Yippy.Domain.Clipboard;

/// <summary>
/// Everything one copy put on the clipboard: the bytes of each format, by format name (see <see cref="ClipboardFormats"/>).
/// </summary>
/// <remarks>Immutable. Two contents with the same formats and bytes have the same <see cref="Hash"/>.</remarks>
public sealed class ClipboardContent
{
    private readonly Dictionary<string, byte[]> formats;
    private string? hash;

    public ClipboardContent(IEnumerable<KeyValuePair<string, byte[]>> formats)
    {
        this.formats = new Dictionary<string, byte[]>(StringComparer.Ordinal);
        foreach (var (name, data) in formats)
        {
            this.formats[name] = data;
        }
    }

    public static ClipboardContent Empty { get; } = new(Array.Empty<KeyValuePair<string, byte[]>>());

    /// <summary>Content holding only this text, as Unicode text.</summary>
    public static ClipboardContent FromText(string text)
    {
        return new ClipboardContent(new[]
        {
            KeyValuePair.Create(ClipboardFormats.UnicodeText, UnicodeText.Encode(text)),
        });
    }

    public IReadOnlyCollection<string> FormatNames => formats.Keys;

    public IReadOnlyDictionary<string, byte[]> Formats => formats;

    public bool IsEmpty => formats.Count == 0;

    public long TotalSize => formats.Values.Sum(d => (long)d.Length);

    public byte[]? Get(string format) => formats.TryGetValue(format, out var data) ? data : null;

    /// <summary>A copy without the formats <paramref name="isRemoved"/> picks.</summary>
    public ClipboardContent Without(Func<string, bool> isRemoved)
    {
        return new ClipboardContent(formats.Where(f => !isRemoved(f.Key)));
    }

    /// <summary>SHA-256 of the format names and bytes, used to find copies of the same content.</summary>
    public string Hash => hash ??= ComputeHash(formats);

    public static string ComputeHash(IEnumerable<KeyValuePair<string, byte[]>> formats)
    {
        using var sha = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
        Span<byte> length = stackalloc byte[8];
        foreach (var (name, data) in formats.OrderBy(f => f.Key, StringComparer.Ordinal))
        {
            var nameBytes = Encoding.UTF8.GetBytes(name);
            BitConverter.TryWriteBytes(length, (long)nameBytes.Length);
            sha.AppendData(length);
            sha.AppendData(nameBytes);
            BitConverter.TryWriteBytes(length, (long)data.Length);
            sha.AppendData(length);
            sha.AppendData(data);
        }
        return Convert.ToHexString(sha.GetHashAndReset());
    }
}
