using System.Text;
using Yippy.Domain.Clipboard;
using Yippy.Domain.Sync;
using Yippy.Domain.Text;
using Yippy.Tests.Fakes;
using Yippy.UseCases.Sync;

namespace Yippy.Tests.Sync;

public class SyncDomainTests
{
    private static readonly SyncKey Key = SyncKey.FromBytes(Enumerable.Range(0, 32).Select(i => (byte)i).ToArray());

    private static SyncContent Text(string text) => new(new[] { KeyValuePair.Create(SyncFormats.Text, Encoding.UTF8.GetBytes(text)) });

    [Fact]
    public void AKeyReadsBackFromItsText()
    {
        var key = SyncKey.Generate();
        var text = key.ToString();

        Assert.Equal(64, text.Length); // 52 characters and 12 dashes
        Assert.True(SyncKey.TryParse(text, out var parsed));
        Assert.Equal(key, parsed);
        Assert.True(SyncKey.TryParse(" " + text.ToLowerInvariant().Replace("-", " ") + "\n", out parsed));
        Assert.Equal(key, parsed);
    }

    [Fact]
    public void LookAlikeLettersReadAsDigits()
    {
        var text = Key.ToString().Replace('0', 'O').Replace('1', 'l');

        Assert.True(SyncKey.TryParse(text, out var parsed));
        Assert.Equal(Key, parsed);
    }

    [Theory]
    [InlineData("")]
    [InlineData("not a key")]
    [InlineData("0000-0000")]
    [InlineData("0000-0000-0000-0000-0000-0000-0000-0000-0000-0000-0000-0000-000U")]
    [InlineData("0000-0000-0000-0000-0000-0000-0000-0000-0000-0000-0000-0000-0001")]
    public void MalformedKeysAreRefused(string text)
    {
        Assert.False(SyncKey.TryParse(text, out _));
    }

    [Fact]
    public void KeysDeriveDifferentSpacesAndTokens()
    {
        var other = SyncKey.Generate();

        Assert.Matches("^[0-9a-f]{32}$", Key.SpaceId);
        Assert.NotEqual(Key.SpaceId, other.SpaceId);
        Assert.NotEqual(Key.AuthToken, other.AuthToken);
    }

    [Fact]
    public void RecordIdsDependOnContentAndKey()
    {
        var hello = SyncRecordKey.For(SyncRecordKind.History, Text("hello"), Key);

        Assert.Equal(hello, SyncRecordKey.For(SyncRecordKind.History, Text("hello"), Key));
        Assert.NotEqual(hello.Id, SyncRecordKey.For(SyncRecordKind.History, Text("hello!"), Key).Id);
        Assert.NotEqual(hello.Id, SyncRecordKey.For(SyncRecordKind.History, Text("hello"), SyncKey.Generate()).Id);
        Assert.Equal(22, hello.Id.Length);
        Assert.Equal("h/" + hello.Id, hello.ToString());
        Assert.Equal(hello, SyncRecordKey.TryParse(hello.ToString()));
    }

    [Fact]
    public void ASealedRecordOpensOnlyWithItsKeyAndUnderItsRecordKey()
    {
        var recordKey = SyncRecordKey.For(SyncRecordKind.Favourite, Text("hi"), Key);
        var payload = new SyncPayload(Text("hi"), DateTimeOffset.FromUnixTimeMilliseconds(1760600000000), "Greeting");

        var data = SyncRecordCodec.Seal(payload, recordKey, Key);

        var opened = SyncRecordCodec.Open(data, recordKey, Key);
        Assert.NotNull(opened);
        Assert.Equal("hi", opened.Content.Text);
        Assert.Equal(payload.CopiedAt, opened.CopiedAt);
        Assert.Equal("Greeting", opened.Title);
        Assert.Null(SyncRecordCodec.Open(data, recordKey, SyncKey.Generate()));
        Assert.Null(SyncRecordCodec.Open(data, recordKey with { Kind = SyncRecordKind.History }, Key));
        data[^1] ^= 1;
        Assert.Null(SyncRecordCodec.Open(data, recordKey, Key));
    }

    [Fact]
    public void PayloadsIgnoreFormatsTheyDontKnow()
    {
        var json = """{"v":1,"copiedAt":5,"formats":{"text":"aGk=","future":"AAAA"}}"""u8.ToArray();

        var payload = SyncRecordCodec.Deserialize(json);

        Assert.NotNull(payload);
        Assert.Equal(new[] { SyncFormats.Text }, payload.Content.Formats.Keys);
        Assert.Null(SyncRecordCodec.Deserialize("""{"v":2,"copiedAt":5,"formats":{}}"""u8.ToArray()));
        Assert.Null(SyncRecordCodec.Deserialize("not json"u8.ToArray()));
    }

    [Fact]
    public void HtmlFragmentsSurviveTheClipboardHeader()
    {
        const string fragment = "<b>bold</b> café";

        var wrapped = HtmlClipboardText.Wrap(fragment);

        Assert.Equal(fragment, HtmlClipboardText.GetFragment(wrapped));
        Assert.Equal("bold café", HtmlClipboardText.ToPlainText(wrapped));
    }

    [Fact]
    public void TheMapperConvertsEverySyncedFormatBothWays()
    {
        var mapper = new SyncFormatMapper(new FakeImageCodec());
        var clipboard = new ClipboardContent(new[]
        {
            KeyValuePair.Create(ClipboardFormats.UnicodeText, UnicodeText.Encode("héllo")),
            KeyValuePair.Create(ClipboardFormats.Rtf, Encoding.ASCII.GetBytes(@"{\rtf1 héllo}" + "\0")),
            KeyValuePair.Create(ClipboardFormats.Html, HtmlClipboardText.Wrap("<i>héllo</i>")),
            KeyValuePair.Create(ClipboardFormats.Dib, new byte[] { 0xD1, 1, 2, 3 }),
            KeyValuePair.Create(ClipboardFormats.FileDrop, new byte[] { 9 }),
        });

        var synced = mapper.ToSync(clipboard);

        Assert.Equal(new[] { "html", "png", "rtf", "text" }, synced.Formats.Keys);
        Assert.Equal("héllo", synced.Text);
        Assert.Equal("<i>héllo</i>", Encoding.UTF8.GetString(synced.Get(SyncFormats.Html)!));
        Assert.Equal(new byte[] { 1, 2, 3 }, synced.Get(SyncFormats.Png));
        Assert.DoesNotContain((byte)0, synced.Get(SyncFormats.Rtf)!);

        var back = mapper.ToClipboard(synced);
        Assert.Equal("héllo", UnicodeText.Decode(back.Get(ClipboardFormats.UnicodeText)!));
        Assert.Equal(new byte[] { 1, 2, 3 }, back.Get(ClipboardFormats.Png));
        Assert.Equal(new byte[] { 0xD1, 1, 2, 3 }, back.Get(ClipboardFormats.Dib));
        Assert.Null(back.Get(ClipboardFormats.FileDrop));
        // Converting again gives the same synced content, so the item keeps its record id
        Assert.Equal(synced.CanonicalBytes(), mapper.ToSync(back).CanonicalBytes());
    }

    [Fact]
    public void CopiedFilesAloneHaveNothingToSync()
    {
        var mapper = new SyncFormatMapper(new FakeImageCodec());

        var synced = mapper.ToSync(new ClipboardContent(new[] { KeyValuePair.Create(ClipboardFormats.FileDrop, new byte[] { 9 }) }));

        Assert.True(synced.IsEmpty);
    }

    [Theory]
    [InlineData("sync.example.com", "https://sync.example.com/")]
    [InlineData("https://sync.example.com:8443/base", "https://sync.example.com:8443/base")]
    [InlineData("http://localhost:8080", "http://localhost:8080/")]
    [InlineData("http://192.168.1.20:8080", "http://192.168.1.20:8080/")]
    public void ServerAddressesAreAccepted(string text, string expected)
    {
        Assert.True(SyncServerAddress.TryParse(text, out var address, out _));
        Assert.Equal(expected, address.ToString());
    }

    [Theory]
    [InlineData("")]
    [InlineData("ftp://sync.example.com")]
    [InlineData("http://sync.example.com")]
    [InlineData("http://8.8.8.8")]
    public void UnsafeOrMalformedServerAddressesAreRefused(string text)
    {
        Assert.False(SyncServerAddress.TryParse(text, out _, out var error));
        Assert.NotNull(error);
    }
}
