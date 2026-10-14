using Yippy.Domain.Apps;
using Yippy.Domain.Clipboard;
using Yippy.Domain.History;
using Yippy.Domain.Search;
using Yippy.Domain.Settings;
using Yippy.Tests.Fakes;
using Yippy.UseCases.Caching;
using Yippy.UseCases.Cleaning;
using Yippy.UseCases.HotKeys;
using Yippy.UseCases.Recognition;
using Yippy.UseCases.Search;
using Yippy.UseCases.Settings;

namespace Yippy.Tests.UseCases;

public class SearchServiceTests
{
    private readonly TestApp app = new();
    private readonly FakeAppInfo appInfo = new();

    private IReadOnlyList<string?> Search(string query)
    {
        var results = new SearchService(appInfo).SearchAsync(query, app.History.Items, CancellationToken.None).Result;
        return results.Select(i => i.PlainText ?? i.Metadata.Title).ToList();
    }

    [Fact]
    public void FindsTextFuzzilyInHistoryOrder()
    {
        app.Clipboard.Copy("hello world");
        app.Clipboard.Copy("goodbye");
        app.Clipboard.Copy("help");

        Assert.Equal(new[] { "help", "hello world" }, Search("HEL"));
        Assert.Equal(3, Search("").Count);
    }

    [Fact]
    public void FiltersByKindAndApp()
    {
        appInfo.Names["Code.exe"] = "Visual Studio Code";
        app.Clipboard.Copy("https://example.com", new AppIdentity("Code.exe"));
        app.Clipboard.Copy("https://example.org", new AppIdentity("msedge.exe"));
        app.Clipboard.Copy("plain words", new AppIdentity("Code.exe"));

        Assert.Equal(new[] { "https://example.org", "https://example.com" }, Search("/link"));
        Assert.Equal(new[] { "plain words", "https://example.com" }, Search("@visualstudio"));
        Assert.Equal(new[] { "https://example.com" }, Search("/url @code example"));
    }

    [Fact]
    public void FindsNamesAndRecognisedText()
    {
        app.Clipboard.Copy("1 Main Street");
        app.History.UpdateMetadata(app.History.Items[0].Id, m => m with { Title = "Home address" });
        app.Clipboard.Copy("other");
        app.History.UpdateMetadata(app.History.Items[0].Id, m => m with { RecognizedText = "invoice total" });

        Assert.Equal(new[] { "1 Main Street" }, Search("home"));
        Assert.Equal(new[] { "other" }, Search("invoice"));
    }

    [Fact]
    public async Task ACancelledSearchStops()
    {
        app.Clipboard.Copy("a");
        using var cancelled = new CancellationTokenSource();
        cancelled.Cancel();

        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => new SearchService(appInfo).SearchAsync("a", app.History.Items, cancelled.Token));
    }
}

public class AutoCleanServiceTests
{
    [Fact]
    public void DeletesExpiredItemsAndClearsTheClipboardWhenTheTopOneGoes()
    {
        var app = new TestApp(AppSettings.Default with { MaxItemAgeDays = 1 });
        var clean = new AutoCleanService(app.History, app.Clipboard, app.Capture, app.Settings, app.Clock);
        app.Clipboard.Copy("old");
        app.Clock.Advance(TimeSpan.FromHours(12));
        app.Clipboard.Copy("newer");
        app.Clock.Advance(TimeSpan.FromHours(13));

        clean.Clean();
        Assert.Equal(new[] { "newer" }, app.Texts);
        Assert.False(app.Clipboard.Content.IsEmpty);

        app.Clock.Advance(TimeSpan.FromHours(12));
        clean.Clean();
        Assert.Empty(app.History.Items);
        Assert.True(app.Clipboard.Content.IsEmpty);
    }

    [Fact]
    public void RunsWhenTheSettingsChange()
    {
        var terminal = new AppIdentity("WindowsTerminal.exe");
        var app = new TestApp();
        _ = new AutoCleanService(app.History, app.Clipboard, app.Capture, app.Settings, app.Clock);
        app.Clipboard.Copy("ls -la", terminal);
        app.Clock.Advance(TimeSpan.FromMinutes(2));

        app.Settings.Update(s => s with { ExpiringApps = new[] { terminal } });

        Assert.Empty(app.History.Items);
    }

    [Fact]
    public void FavouritesAreNeverCleaned()
    {
        var app = new TestApp(AppSettings.Default with { MaxItemAgeDays = 1 });
        var clean = new AutoCleanService(app.History, app.Clipboard, app.Capture, app.Settings, app.Clock);
        app.Clipboard.Copy("keep me");
        app.Editing.ToggleFavourite(app.History.Items[0]);
        app.Clock.Advance(TimeSpan.FromDays(3));

        clean.Clean();

        Assert.Single(app.Favourites.Items);
    }
}

public class TextRecognitionServiceTests
{
    private static ClipboardContent Image(byte marker) => new(new[] { KeyValuePair.Create(ClipboardFormats.Png, new byte[] { 0x89, marker }) });

    [Fact]
    public void ReadsNewImagesOnlyWhileTurnedOn()
    {
        var app = new TestApp();
        var recognizer = new FakeTextRecognizer();
        _ = new TextRecognitionService(recognizer, app.Settings, new RecordingLogger(), app.History, app.Favourites);

        app.Clipboard.Copy(Image(1));
        Assert.Null(app.History.Items[0].Metadata.RecognizedText);

        app.Settings.Update(s => s with { RecognizesTextInImages = true });
        Assert.Equal("recognised", app.History.Items[0].Metadata.RecognizedText);

        app.Clipboard.Copy(Image(2));
        app.Clipboard.Copy("text is not read");
        Assert.Equal("recognised", app.History.Items[1].Metadata.RecognizedText);
        Assert.Equal(2, recognizer.Reads);
    }

    [Fact]
    public void RemembersImagesWithoutTextSoTheyAreNotReadAgain()
    {
        var app = new TestApp(AppSettings.Default with { RecognizesTextInImages = true });
        var recognizer = new FakeTextRecognizer { Recognize = _ => "" };
        _ = new TextRecognitionService(recognizer, app.Settings, new RecordingLogger(), app.History);

        app.Clipboard.Copy(Image(1));
        app.Settings.Update(s => s with { RecognizesTextInImages = false });
        app.Settings.Update(s => s with { RecognizesTextInImages = true });

        Assert.Equal("", app.History.Items[0].Metadata.RecognizedText);
        Assert.Equal(1, recognizer.Reads);
    }

    [Fact]
    public void FailuresAreLoggedAndSkipped()
    {
        var app = new TestApp(AppSettings.Default with { RecognizesTextInImages = true });
        var logger = new RecordingLogger();
        var recognizer = new FakeTextRecognizer { Recognize = _ => throw new InvalidOperationException("broken") };
        _ = new TextRecognitionService(recognizer, app.Settings, logger, app.History);

        app.Clipboard.Copy(Image(1));

        Assert.Null(app.History.Items[0].Metadata.RecognizedText);
        Assert.Single(logger.Warnings);
    }
}

public class ToggleHotKeyServiceTests
{
    private readonly FakeGlobalHotKeys hotKeys = new();
    private readonly SettingsService settings = new(new InMemorySettingsRepository());

    [Fact]
    public void RegistersTheSavedShortcut()
    {
        var service = new ToggleHotKeyService(hotKeys, settings);
        var presses = 0;

        Assert.True(service.Start(() => presses++));
        hotKeys.Press(HotKeyGesture.DefaultToggle);

        Assert.Equal(1, presses);
    }

    [Fact]
    public void ChangingToAShortcutInUseKeepsTheOldOne()
    {
        var service = new ToggleHotKeyService(hotKeys, settings);
        service.Start(() => { });
        var taken = new HotKeyGesture('C', KeyModifiers.Control | KeyModifiers.Alt);
        hotKeys.TakenByOtherApps.Add(taken);

        Assert.False(service.TryChange(taken));
        Assert.Equal(HotKeyGesture.DefaultToggle, settings.Current.ToggleHotKey);
        Assert.True(hotKeys.Registered.ContainsKey(HotKeyGesture.DefaultToggle));
    }

    [Fact]
    public void ChangingSavesTheNewShortcut()
    {
        var service = new ToggleHotKeyService(hotKeys, settings);
        service.Start(() => { });
        var gesture = new HotKeyGesture('Q', KeyModifiers.Control | KeyModifiers.Alt);

        Assert.True(service.TryChange(gesture));
        Assert.Equal(gesture, settings.Current.ToggleHotKey);
        Assert.Equal(new[] { gesture }, hotKeys.Registered.Keys);
        Assert.False(service.TryChange(new HotKeyGesture('Q', KeyModifiers.None)));
    }

    [Fact]
    public void ChangingWhileSuspendedRegistersOnlyOnResume()
    {
        var service = new ToggleHotKeyService(hotKeys, settings);
        service.Start(() => { });
        service.Suspend();
        var gesture = new HotKeyGesture('Q', KeyModifiers.Control | KeyModifiers.Alt);

        Assert.True(service.TryChange(gesture));
        Assert.Empty(hotKeys.Registered);
        service.Resume();
        Assert.Equal(new[] { gesture }, hotKeys.Registered.Keys);
    }

    [Fact]
    public void SuspendingLetsTheShortcutThrough()
    {
        var service = new ToggleHotKeyService(hotKeys, settings);
        service.Start(() => { });

        service.Suspend();
        Assert.Empty(hotKeys.Registered);
        service.Resume();
        Assert.Single(hotKeys.Registered);
    }
}

public class WindowsClipboardShortcutServiceTests
{
    private readonly FakeGlobalHotKeys hotKeys = new();
    private readonly SettingsService settings = new(new InMemorySettingsRepository());
    private readonly FakeShellClipboardShortcut shell;
    private readonly ToggleHotKeyService toggle;
    private readonly WindowsClipboardShortcutService service;

    public WindowsClipboardShortcutServiceTests()
    {
        shell = new FakeShellClipboardShortcut(hotKeys);
        toggle = new ToggleHotKeyService(hotKeys, settings);
        toggle.Start(() => { });
        service = new WindowsClipboardShortcutService(shell, toggle);
    }

    [Fact]
    public void WinVBelongsToWindowsAtFirst()
    {
        Assert.False(service.IsTakenOver);
        Assert.False(service.OpensYippy);
        Assert.False(toggle.TryChange(HotKeyGesture.WindowsClipboard));
    }

    [Fact]
    public async Task TakingOverReleasesWinVFromExplorerAndRegistersIt()
    {
        Assert.True(await service.TakeOverAsync());

        Assert.True(service.OpensYippy);
        Assert.Equal(1, shell.Restarts);
        Assert.Equal(HotKeyGesture.WindowsClipboard, settings.Current.ToggleHotKey);
        Assert.Equal(new[] { HotKeyGesture.WindowsClipboard }, hotKeys.Registered.Keys);
    }

    [Fact]
    public async Task RestoringGivesWinVBackAndSwitchesToTheReplacement()
    {
        await service.TakeOverAsync();

        Assert.True(await service.RestoreAsync(HotKeyGesture.DefaultToggle));

        Assert.False(service.IsTakenOver);
        Assert.False(shell.IsReleased);
        Assert.Equal(2, shell.Restarts);
        Assert.Equal(HotKeyGesture.DefaultToggle, settings.Current.ToggleHotKey);
        Assert.Contains(HotKeyGesture.WindowsClipboard, hotKeys.TakenByOtherApps);
    }

    [Fact]
    public async Task RestoringAfterChoosingAnotherShortcutKeepsThatShortcut()
    {
        await service.TakeOverAsync();
        var other = new HotKeyGesture('Q', KeyModifiers.Control | KeyModifiers.Alt);
        toggle.TryChange(other);
        Assert.True(service.IsTakenOver);
        Assert.False(service.OpensYippy);

        Assert.True(await service.RestoreAsync(HotKeyGesture.DefaultToggle));

        Assert.False(service.IsTakenOver);
        Assert.Equal(other, settings.Current.ToggleHotKey);
    }

    [Fact]
    public async Task RestoringChangesNothingWhenTheReplacementIsTaken()
    {
        await service.TakeOverAsync();
        hotKeys.TakenByOtherApps.Add(HotKeyGesture.DefaultToggle);

        Assert.False(await service.RestoreAsync(HotKeyGesture.DefaultToggle));

        Assert.True(service.IsTakenOver);
        Assert.Equal(1, shell.Restarts);
    }
}

public class SettingsServiceTests
{
    [Fact]
    public void SavesAndAnnouncesOnlyRealChanges()
    {
        var repository = new InMemorySettingsRepository();
        var settings = new SettingsService(repository);
        var changes = 0;
        settings.Changed += (_, _) => changes++;

        Assert.True(settings.IsFirstLaunch);
        settings.Update(s => s with { MaxHistory = 50 });
        settings.Update(s => s with { MaxHistory = 50 });

        Assert.Equal(1, changes);
        Assert.Equal(1, repository.Saves);
        Assert.Equal(50, repository.Saved!.MaxHistory);
    }

    [Fact]
    public void TheHistoryLengthFollowsTheSetting()
    {
        var app = new TestApp();
        foreach (var text in new[] { "a", "b", "c" })
        {
            app.Clipboard.Copy(text);
        }

        app.Settings.Update(s => s with { MaxHistory = 2 });

        Assert.Equal(new[] { "c", "b" }, app.Texts);
        Assert.Equal(2, app.History.MaxItems);
    }
}

public class LruCacheTests
{
    [Fact]
    public void EvictsTheLeastRecentlyUsed()
    {
        var cache = new LruCache<string, byte[]>(10, v => v.Length);
        cache.Set("a", new byte[4]);
        cache.Set("b", new byte[4]);
        Assert.True(cache.TryGet("a", out _));

        cache.Set("c", new byte[4]);

        Assert.True(cache.TryGet("a", out _));
        Assert.False(cache.TryGet("b", out _));
        Assert.True(cache.TryGet("c", out _));
        Assert.Equal(8, cache.Size);
    }

    [Fact]
    public void DoesNotKeepValuesLargerThanItself()
    {
        var cache = new LruCache<string, byte[]>(10, v => v.Length);
        cache.Set("big", new byte[11]);

        Assert.False(cache.TryGet("big", out _));
        Assert.Equal(0, cache.Size);
    }

    [Fact]
    public void CachingDataSourceReadsEachFormatOnce()
    {
        var inner = new CountingSource();
        var source = new CachingItemDataSource(inner);
        var id = Guid.NewGuid();

        source.Read(id, "A");
        source.Read(id, "A");

        Assert.Equal(1, inner.Reads);
    }

    private sealed class CountingSource : IItemDataSource
    {
        public int Reads { get; private set; }

        public byte[]? Read(Guid itemId, string format)
        {
            Reads++;
            return new byte[] { 1 };
        }
    }
}

public class HistoryItemTests
{
    [Fact]
    public void DescribesItemsByWhatTheyHold()
    {
        var app = new TestApp();
        app.Clipboard.Copy(new ClipboardContent(new[]
        {
            KeyValuePair.Create(ClipboardFormats.Rtf, System.Text.Encoding.ASCII.GetBytes(@"{\rtf1 styled \b text}")),
        }));
        app.Clipboard.Copy("#00ff00");

        Assert.Equal(ItemKind.Color, app.History.Items[0].Kind);
        Assert.Null(app.History.Items[1].PlainText);
        Assert.Equal("styled text", app.History.Items[1].GetUnstyledText());
        Assert.Equal("styled text", app.History.Items[1].GetDisplayText());
    }
}
