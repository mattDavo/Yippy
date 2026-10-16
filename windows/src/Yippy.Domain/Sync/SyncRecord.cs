using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Yippy.Domain.Sync;

/// <summary>What one record says: the item's content, when it was copied and, for favourites, its name.</summary>
public sealed record SyncPayload(SyncContent Content, DateTimeOffset CopiedAt, string? Title = null);

/// <summary>
/// Turns payloads into the encrypted data the server stores and back: JSON, then AES-256-GCM with the record key as
/// additional data (see sync-server/PROTOCOL.md).
/// </summary>
public static class SyncRecordCodec
{
    private const byte Version = 1;
    private const int NonceSize = 12;
    private const int TagSize = 16;

    public static byte[] Seal(SyncPayload payload, SyncRecordKey recordKey, SyncKey key)
    {
        return Seal(Serialize(payload), recordKey, key, RandomNumberGenerator.GetBytes(NonceSize));
    }

    /// <summary>Like <see cref="Seal(SyncPayload, SyncRecordKey, SyncKey)"/> with a chosen nonce, for test vectors.</summary>
    public static byte[] Seal(byte[] plaintext, SyncRecordKey recordKey, SyncKey key, byte[] nonce)
    {
        var data = new byte[1 + NonceSize + plaintext.Length + TagSize];
        data[0] = Version;
        nonce.CopyTo(data, 1);
        using var aes = new AesGcm(key.EncryptionKey, TagSize);
        aes.Encrypt(nonce, plaintext, data.AsSpan(1 + NonceSize, plaintext.Length), data.AsSpan(1 + NonceSize + plaintext.Length),
            Encoding.UTF8.GetBytes(recordKey.ToString()));
        return data;
    }

    /// <returns>The payload, or null if the data is damaged, from another key or not a version this app reads.</returns>
    public static SyncPayload? Open(byte[] data, SyncRecordKey recordKey, SyncKey key)
    {
        if (data.Length < 1 + NonceSize + TagSize || data[0] != Version)
        {
            return null;
        }
        var plaintext = new byte[data.Length - 1 - NonceSize - TagSize];
        try
        {
            using var aes = new AesGcm(key.EncryptionKey, TagSize);
            aes.Decrypt(data.AsSpan(1, NonceSize), data.AsSpan(1 + NonceSize, plaintext.Length), data.AsSpan(data.Length - TagSize), plaintext,
                Encoding.UTF8.GetBytes(recordKey.ToString()));
        }
        catch (CryptographicException)
        {
            return null;
        }
        return Deserialize(plaintext);
    }

    public static byte[] Serialize(SyncPayload payload)
    {
        var json = new PayloadJson
        {
            V = 1,
            CopiedAt = payload.CopiedAt.ToUnixTimeMilliseconds(),
            Title = payload.Title,
            Formats = payload.Content.Formats.ToDictionary(f => f.Key, f => Convert.ToBase64String(f.Value)),
        };
        return JsonSerializer.SerializeToUtf8Bytes(json, Options);
    }

    public static SyncPayload? Deserialize(byte[] json)
    {
        try
        {
            var parsed = JsonSerializer.Deserialize<PayloadJson>(json, Options);
            if (parsed is null || parsed.V != 1 || parsed.Formats is null)
            {
                return null;
            }
            var formats = parsed.Formats
                .Where(f => SyncFormats.All.Contains(f.Key))
                .Select(f => KeyValuePair.Create(f.Key, Convert.FromBase64String(f.Value)));
            return new SyncPayload(new SyncContent(formats), DateTimeOffset.FromUnixTimeMilliseconds(parsed.CopiedAt), parsed.Title);
        }
        catch (Exception e) when (e is JsonException or FormatException or ArgumentOutOfRangeException)
        {
            return null;
        }
    }

    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
    };

    private sealed class PayloadJson
    {
        public int V { get; set; }

        public long CopiedAt { get; set; }

        public string? Title { get; set; }

        public Dictionary<string, string>? Formats { get; set; }
    }
}
