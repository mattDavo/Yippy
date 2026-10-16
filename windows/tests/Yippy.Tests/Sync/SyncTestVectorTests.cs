using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Nodes;
using Yippy.Domain.Sync;

namespace Yippy.Tests.Sync;

/// <summary>
/// Checks this implementation against sync-server/test-vectors.json, which the macOS tests check too, so both apps read
/// each other's records. Set SYNC_WRITE_TEST_VECTORS=1 to write the file from this implementation instead.
/// </summary>
public class SyncTestVectorTests
{
    private static readonly SyncKey Key = SyncKey.FromBytes(Enumerable.Range(0, 32).Select(i => (byte)(i * 7 + 3)).ToArray());

    private static readonly (string Kind, Dictionary<string, string> Formats, long CopiedAt, string? Title, string Nonce)[] Cases =
    {
        ("h", new() { ["text"] = "hello" }, 1760600000000, null, "000102030405060708090a0b"),
        ("f", new() { ["text"] = "Grüße 👋", ["html"] = "<b>Grüße</b> 👋" }, 1760600123456, "Greeting", "0c0d0e0f1011121314151617"),
    };

    [Fact]
    public void ThisImplementationMatchesTheTestVectors()
    {
        var expected = Build();
        var path = VectorsPath();
        if (Environment.GetEnvironmentVariable("SYNC_WRITE_TEST_VECTORS") == "1")
        {
            var options = new JsonSerializerOptions { WriteIndented = true, Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping };
            File.WriteAllText(path, expected.ToJsonString(options) + "\n");
        }

        var saved = JsonNode.Parse(File.ReadAllText(path))!;

        Assert.Equal(expected.ToJsonString(), saved.ToJsonString());
    }

    [Fact]
    public void TheVectorsRecordsOpen()
    {
        var saved = JsonNode.Parse(File.ReadAllText(VectorsPath()))!;
        Assert.True(SyncKey.TryParse(saved["key"]!.GetValue<string>(), out var key));

        foreach (var record in saved["records"]!.AsArray())
        {
            var recordKey = SyncRecordKey.TryParse(record!["recordKey"]!.GetValue<string>())!;
            var payload = SyncRecordCodec.Open(Convert.FromBase64String(record["sealed"]!.GetValue<string>()), recordKey, key);

            Assert.NotNull(payload);
            Assert.Equal(record["copiedAt"]!.GetValue<long>(), payload.CopiedAt.ToUnixTimeMilliseconds());
            Assert.Equal(record["title"]?.GetValue<string>(), payload.Title);
            Assert.Equal(record["formats"]!["text"]!.GetValue<string>(), payload.Content.Text);
        }
    }

    private static JsonObject Build()
    {
        var records = new JsonArray();
        foreach (var (kind, formats, copiedAt, title, nonce) in Cases)
        {
            var content = new SyncContent(formats.Select(f => KeyValuePair.Create(f.Key, Encoding.UTF8.GetBytes(f.Value))));
            var recordKey = SyncRecordKey.For(kind == "h" ? SyncRecordKind.History : SyncRecordKind.Favourite, content, Key);
            var plaintext = SyncRecordCodec.Serialize(new SyncPayload(content, DateTimeOffset.FromUnixTimeMilliseconds(copiedAt), title));
            var sealedData = SyncRecordCodec.Seal(plaintext, recordKey, Key, Convert.FromHexString(nonce));
            var formatsJson = new JsonObject();
            foreach (var (name, value) in formats.OrderBy(f => f.Key, StringComparer.Ordinal))
            {
                formatsJson[name] = value;
            }
            records.Add(new JsonObject
            {
                ["comment"] = "formats are UTF-8 text here; in payloads they are base64",
                ["formats"] = formatsJson,
                ["canonicalBytes"] = Convert.ToHexString(content.CanonicalBytes()).ToLowerInvariant(),
                ["recordKey"] = recordKey.ToString(),
                ["copiedAt"] = copiedAt,
                ["title"] = title,
                ["nonce"] = nonce,
                ["plaintext"] = Encoding.UTF8.GetString(plaintext),
                ["sealed"] = Convert.ToBase64String(sealedData),
            });
        }
        return new JsonObject
        {
            ["comment"] = "Known answers for sync-server/PROTOCOL.md. The Windows tests write this file; both apps' tests check it.",
            ["keyBytes"] = Convert.ToHexString(Key.ToBytes()).ToLowerInvariant(),
            ["key"] = Key.ToString(),
            ["spaceId"] = Key.SpaceId,
            ["authToken"] = Key.AuthToken,
            ["records"] = records,
        };
    }

    private static string VectorsPath()
    {
        for (var directory = new DirectoryInfo(AppContext.BaseDirectory); directory is not null; directory = directory.Parent)
        {
            var candidate = Path.Combine(directory.FullName, "sync-server", "test-vectors.json");
            if (Directory.Exists(Path.Combine(directory.FullName, "sync-server")))
            {
                return candidate;
            }
        }
        throw new DirectoryNotFoundException("Couldn't find the sync-server folder above the test binaries.");
    }
}
