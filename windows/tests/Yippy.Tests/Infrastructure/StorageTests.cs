using System.Text.Json;
using Yippy.Domain.Apps;
using Yippy.Domain.Clipboard;
using Yippy.Domain.History;
using Yippy.Domain.Settings;
using Yippy.Infrastructure.Settings;
using Yippy.Infrastructure.Storage;
using Yippy.Tests.Fakes;
using Yippy.UseCases.History;

namespace Yippy.Tests.Infrastructure;

/// <summary>A folder that is deleted after the test.</summary>
public sealed class TemporaryDirectory : IDisposable
{
    public string Path { get; } = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "yippy-tests-" + Guid.NewGuid());

    public TemporaryDirectory() => Directory.CreateDirectory(Path);

    public void Dispose()
    {
        if (Directory.Exists(Path))
        {
            Directory.Delete(Path, recursive: true);
        }
    }
}

public sealed class FileHistoryRepositoryTests : IDisposable
{
    private readonly TemporaryDirectory directory = new();
    private readonly RecordingLogger logger = new();

    public void Dispose() => directory.Dispose();

    private static ClipboardContent RichText(string text) => new(new[]
    {
        KeyValuePair.Create(ClipboardFormats.UnicodeText, Yippy.Domain.Text.UnicodeText.Encode(text)),
        KeyValuePair.Create(ClipboardFormats.Rtf, System.Text.Encoding.ASCII.GetBytes(@"{\rtf1 " + text + "}")),
        KeyValuePair.Create("text/x:odd*name", new byte[] { 1, 2, 3 }),
    });

    [Fact]
    public async Task ItemsSurviveARestart()
    {
        Guid firstId;
        using (var repository = new FileHistoryRepository(directory.Path, logger))
        {
            var history = new ItemHistory(repository, repository, 10, movesPastedItemToTop: true);
            firstId = history.Add(RichText("first"), new ItemMetadata { Title = "One", Source = AppIdentity.FromPath(@"C:\a\Code.exe") }).Id;
            history.Add(RichText("second"), ItemMetadata.None);
            await repository.FlushAsync();
        }

        using var reopened = new FileHistoryRepository(directory.Path, logger);
        var loaded = new ItemHistory(reopened, reopened, 10, movesPastedItemToTop: true);

        Assert.Equal(new[] { "second", "first" }, loaded.Items.Select(i => i.PlainText));
        var first = loaded.Items[1];
        Assert.Equal(firstId, first.Id);
        Assert.Equal("One", first.Metadata.Title);
        Assert.Equal(@"C:\a\Code.exe", first.Metadata.Source!.Path);
        Assert.Equal(RichText("first").Hash, first.ContentHash);
        Assert.Equal(new byte[] { 1, 2, 3 }, first.GetData("text/x:odd*name"));
        Assert.Empty(logger.Warnings);
    }

    [Fact]
    public void ItemsCanBeReadBeforeTheyAreWritten()
    {
        using var repository = new FileHistoryRepository(directory.Path, logger);
        var id = Guid.NewGuid();

        repository.Add(id, ClipboardContent.FromText("now"));

        Assert.NotNull(repository.Read(id, ClipboardFormats.UnicodeText));
    }

    [Fact]
    public async Task DeletedItemsLeaveNothingBehind()
    {
        using var repository = new FileHistoryRepository(directory.Path, logger);
        var history = new ItemHistory(repository, repository, 10, movesPastedItemToTop: true);
        var item = history.Add(ClipboardContent.FromText("gone"), ItemMetadata.None);
        history.Add(ClipboardContent.FromText("kept"), ItemMetadata.None);

        history.Delete(item.Id);
        await repository.FlushAsync();

        Assert.False(Directory.Exists(System.IO.Path.Combine(directory.Path, item.Id.ToString())));
        history.Clear();
        await repository.FlushAsync();
        Assert.Empty(Directory.GetDirectories(directory.Path));
    }

    [Fact]
    public async Task ReconcilesTheIndexWithTheFolders()
    {
        Guid missing, unindexed;
        using (var repository = new FileHistoryRepository(directory.Path, logger))
        {
            var history = new ItemHistory(repository, repository, 10, movesPastedItemToTop: true);
            missing = history.Add(ClipboardContent.FromText("missing"), ItemMetadata.None).Id;
            history.Add(ClipboardContent.FromText("indexed"), ItemMetadata.None);
            await repository.FlushAsync();
        }
        Directory.Delete(System.IO.Path.Combine(directory.Path, missing.ToString()), recursive: true);
        unindexed = Guid.NewGuid();
        var folder = Directory.CreateDirectory(System.IO.Path.Combine(directory.Path, unindexed.ToString())).FullName;
        File.WriteAllBytes(System.IO.Path.Combine(folder, FormatFileName.Encode(ClipboardFormats.UnicodeText)), ClipboardContent.FromText("unindexed").Get(ClipboardFormats.UnicodeText)!);
        Directory.CreateDirectory(System.IO.Path.Combine(directory.Path, Guid.NewGuid().ToString()));

        using var reopened = new FileHistoryRepository(directory.Path, logger);
        var items = reopened.Load();

        Assert.Equal(new[] { "indexed", "unindexed" }, items.Select(i => Yippy.Domain.Text.UnicodeText.Decode(reopened.Read(i.Id, ClipboardFormats.UnicodeText)!)));
        Assert.Equal(ClipboardContent.FromText("unindexed").Hash, items[1].ContentHash);
        Assert.Equal(3, logger.Warnings.Count);
    }

    [Fact]
    public void AnUnreadableIndexStillLoadsTheItems()
    {
        var id = Guid.NewGuid();
        var folder = Directory.CreateDirectory(System.IO.Path.Combine(directory.Path, id.ToString())).FullName;
        File.WriteAllBytes(System.IO.Path.Combine(folder, FormatFileName.Encode(ClipboardFormats.UnicodeText)), ClipboardContent.FromText("x").Get(ClipboardFormats.UnicodeText)!);
        File.WriteAllText(System.IO.Path.Combine(directory.Path, FileHistoryRepository.IndexFileName), "{ not json");

        using var repository = new FileHistoryRepository(directory.Path, logger);

        Assert.Single(repository.Load());
        Assert.Single(logger.Errors);
    }

    [Theory]
    [InlineData("CF_UNICODETEXT")]
    [InlineData("Rich Text Format")]
    [InlineData("text/html; charset=utf-8")]
    [InlineData("100%")]
    [InlineData("CON")]
    [InlineData("名前")]
    public void FormatNamesRoundTripThroughSafeFileNames(string format)
    {
        var fileName = FormatFileName.Encode(format);

        Assert.Matches("^[A-Za-z0-9_%-]+$", fileName);
        Assert.NotEqual("CON", fileName);
        Assert.Equal(format, FormatFileName.Decode(fileName));
    }
}

public sealed class JsonSettingsRepositoryTests : IDisposable
{
    private readonly TemporaryDirectory directory = new();
    private readonly RecordingLogger logger = new();

    public void Dispose() => directory.Dispose();

    private string SettingsPath => System.IO.Path.Combine(directory.Path, "settings.json");

    [Fact]
    public void NoFileMeansFirstLaunch()
    {
        Assert.Null(new JsonSettingsRepository(SettingsPath, logger).Load());
    }

    [Fact]
    public void RoundTrips()
    {
        var repository = new JsonSettingsRepository(SettingsPath, logger);
        var settings = AppSettings.Default with
        {
            PanelPosition = PanelPosition.CenterLarge,
            ToggleHotKey = new HotKeyGesture('B', KeyModifiers.Control | KeyModifiers.Windows),
            IgnoredApps = new[] { AppIdentity.FromPath(@"C:\Program Files\KeePass\KeePass.exe") },
            ClipboardSequenceNumber = 42,
        };

        repository.Save(settings);
        var loaded = repository.Load()!;

        Assert.Equal(settings.PanelPosition, loaded.PanelPosition);
        Assert.Equal(settings.ToggleHotKey, loaded.ToggleHotKey);
        Assert.Equal(settings.IgnoredApps, loaded.IgnoredApps);
        Assert.Equal(@"C:\Program Files\KeePass\KeePass.exe", loaded.IgnoredApps[0].Path);
        Assert.Equal(42u, loaded.ClipboardSequenceNumber);
        Assert.DoesNotContain("IsValid", File.ReadAllText(SettingsPath));
    }

    [Fact]
    public void ValuesMissingFromOlderFilesTakeTheirDefaults()
    {
        File.WriteAllText(SettingsPath, "{ \"PanelPosition\": \"Left\", \"MaxHistory\": 100 }");

        var loaded = new JsonSettingsRepository(SettingsPath, logger).Load()!;

        Assert.Equal(PanelPosition.Left, loaded.PanelPosition);
        Assert.Equal(100, loaded.MaxHistory);
        Assert.Equal(HotKeyGesture.DefaultToggle, loaded.ToggleHotKey);
        Assert.True(loaded.PastesRichText);
        Assert.Empty(loaded.IgnoredApps);
    }

    [Fact]
    public void AnUnreadableFileFallsBackToTheDefaultsAndIsKept()
    {
        File.WriteAllText(SettingsPath, "{ broken");

        var loaded = new JsonSettingsRepository(SettingsPath, logger).Load();

        Assert.Equal(AppSettings.Default.MaxHistory, loaded!.MaxHistory);
        Assert.True(File.Exists(SettingsPath + ".unreadable"));
        Assert.Single(logger.Errors);
    }

    [Fact]
    public void ComputedPropertiesAreNotWritten()
    {
        var json = JsonSerializer.Serialize(new AppIdentity("a.exe"), JsonDefaults.Options);

        Assert.Equal("{\n  \"Id\": \"a.exe\",\n  \"Path\": null\n}", json.ReplaceLineEndings("\n"));
    }
}
