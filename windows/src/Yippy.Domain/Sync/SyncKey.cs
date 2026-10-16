using System.Security.Cryptography;
using System.Text;

namespace Yippy.Domain.Sync;

/// <summary>
/// The secret every device of one user shares to sync (see sync-server/PROTOCOL.md). Shown as Crockford base32 in groups
/// of four; everything sent to the server and the encryption keys are derived from it.
/// </summary>
public sealed class SyncKey : IEquatable<SyncKey>
{
    public const int Length = 32;

    private const string Alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";

    private readonly byte[] bytes;

    private SyncKey(byte[] bytes)
    {
        this.bytes = bytes;
        SpaceId = Convert.ToHexString(Derive("space", 16)).ToLowerInvariant();
        AuthToken = Base64Url.Encode(Derive("auth", 32));
        EncryptionKey = Derive("encrypt", 32);
        IdKey = Derive("id", 32);
    }

    /// <summary>Which space on the server holds this key's records.</summary>
    public string SpaceId { get; }

    /// <summary>Proves to the server that a device may use the space.</summary>
    public string AuthToken { get; }

    /// <summary>The AES-256-GCM key. Never leaves the device.</summary>
    internal byte[] EncryptionKey { get; }

    /// <summary>The HMAC key for record ids. Never leaves the device.</summary>
    internal byte[] IdKey { get; }

    public static SyncKey Generate() => new(RandomNumberGenerator.GetBytes(Length));

    public static SyncKey FromBytes(ReadOnlySpan<byte> bytes)
    {
        if (bytes.Length != Length)
        {
            throw new ArgumentException($"A sync key is {Length} bytes.", nameof(bytes));
        }
        return new SyncKey(bytes.ToArray());
    }

    /// <summary>Reads a key as <see cref="ToString"/> writes it, ignoring case, spaces and dashes.</summary>
    public static bool TryParse(string? text, out SyncKey key)
    {
        key = null!;
        if (text is null)
        {
            return false;
        }
        var bits = 0;
        var value = 0;
        var output = new List<byte>(Length);
        foreach (var raw in text)
        {
            if (raw is '-' or ' ' or '\t' or '\r' or '\n')
            {
                continue;
            }
            var c = char.ToUpperInvariant(raw) switch
            {
                'O' => '0',
                'I' or 'L' => '1',
                var other => other,
            };
            var digit = Alphabet.IndexOf(c);
            if (digit < 0)
            {
                return false;
            }
            value = (value << 5) | digit;
            bits += 5;
            if (bits >= 8)
            {
                bits -= 8;
                output.Add((byte)(value >> bits));
                value &= (1 << bits) - 1;
            }
        }
        // 52 characters hold 260 bits: 256 for the key, and 4 that must be zero
        if (output.Count != Length || value != 0)
        {
            return false;
        }
        key = new SyncKey(output.ToArray());
        return true;
    }

    public byte[] ToBytes() => bytes.ToArray();

    /// <summary>52 characters of Crockford base32, in groups of four separated by dashes.</summary>
    public override string ToString()
    {
        var text = new StringBuilder();
        var bits = 0;
        var value = 0;
        foreach (var b in bytes)
        {
            value = (value << 8) | b;
            bits += 8;
            while (bits >= 5)
            {
                bits -= 5;
                text.Append(Alphabet[(value >> bits) & 31]);
            }
        }
        if (bits > 0)
        {
            text.Append(Alphabet[(value << (5 - bits)) & 31]);
        }
        return string.Join('-', text.ToString().Chunk(4).Select(c => new string(c)));
    }

    public bool Equals(SyncKey? other) => other is not null && CryptographicOperations.FixedTimeEquals(bytes, other.bytes);

    public override bool Equals(object? obj) => Equals(obj as SyncKey);

    public override int GetHashCode() => SpaceId.GetHashCode();

    private byte[] Derive(string purpose, int length)
    {
        return HKDF.Expand(HashAlgorithmName.SHA256, HKDF.Extract(HashAlgorithmName.SHA256, bytes), length,
            Encoding.UTF8.GetBytes("clipsync-v1 " + purpose));
    }
}

/// <summary>Base64url without padding (RFC 4648 §5).</summary>
public static class Base64Url
{
    public static string Encode(ReadOnlySpan<byte> data)
    {
        return Convert.ToBase64String(data).TrimEnd('=').Replace('+', '-').Replace('/', '_');
    }
}
