using Yippy.Domain.Apps;
using Yippy.Domain.Clipboard;
using Yippy.Domain.Settings;
using Yippy.Domain.Sync;
using Yippy.Tests.Fakes;
using Yippy.UseCases.Sync;

namespace Yippy.Tests.Sync;

public class SyncServiceTests
{
    private readonly FakeSyncServer server = new();
    private readonly SyncKey key = SyncKey.Generate();

    private SyncDevice NewDevice(AppSettings? settings = null) => new(server, key, settings);

    private static async Task SyncAll(params SyncDevice[] devices)
    {
        // Twice round, so every device sees what the others sent
        for (var round = 0; round < 2; round++)
        {
            foreach (var device in devices)
            {
                await device.SyncAsync();
            }
        }
    }

    [Fact]
    public async Task ACopyShowsUpOnTheOtherDevice()
    {
        var mac = NewDevice();
        var pc = NewDevice();

        mac.App.Clipboard.Copy("hello");
        await SyncAll(mac, pc);

        Assert.Equal(new[] { "hello" }, pc.Texts);
        Assert.Equal(new[] { "hello" }, mac.Texts);
        Assert.Equal(mac.App.Clock.Now, pc.App.History.Items[0].Metadata.CopiedAt);
    }

    [Fact]
    public async Task SyncedCopiesTakeTheirPlaceByWhenTheyWereCopied()
    {
        var a = NewDevice();
        var b = NewDevice();
        b.App.Clock.Now = a.App.Clock.Now;

        a.App.Clipboard.Copy("first");
        b.App.Clock.Advance(TimeSpan.FromMinutes(1));
        b.App.Clipboard.Copy("second");
        a.App.Clock.Advance(TimeSpan.FromMinutes(2));
        a.App.Clipboard.Copy("third");
        await SyncAll(a, b);

        Assert.Equal(new[] { "third", "second", "first" }, a.Texts);
        Assert.Equal(new[] { "third", "second", "first" }, b.Texts);
    }

    [Fact]
    public async Task CopyingAgainMovesTheItemUpEverywhereWithoutDuplicates()
    {
        var a = NewDevice();
        var b = NewDevice();
        a.App.Clipboard.Copy("one");
        a.App.Clock.Advance(TimeSpan.FromMinutes(1));
        a.App.Clipboard.Copy("two");
        await SyncAll(a, b);

        b.App.Clock.Now = a.App.Clock.Now + TimeSpan.FromMinutes(1);
        b.App.Clipboard.Copy("one");
        await SyncAll(a, b);

        Assert.Equal(new[] { "one", "two" }, a.Texts);
        Assert.Equal(new[] { "one", "two" }, b.Texts);
        Assert.Equal(2, server.LiveKeys.Count());
    }

    [Fact]
    public async Task TheSameTextCopiedOnBothDevicesIsOneItem()
    {
        var a = NewDevice();
        var b = NewDevice();

        a.App.Clipboard.Copy("same");
        b.App.Clipboard.Copy("same");
        await SyncAll(a, b);

        Assert.Equal(new[] { "same" }, a.Texts);
        Assert.Equal(new[] { "same" }, b.Texts);
        Assert.Single(server.LiveKeys);
    }

    [Fact]
    public async Task DeletingAnItemDeletesItEverywhere()
    {
        var a = NewDevice();
        var b = NewDevice();
        a.App.Clipboard.Copy("password123");
        a.App.Clipboard.Copy("keep");
        await SyncAll(a, b);

        b.App.Editing.Delete(b.App.History, b.App.History.Items.Single(i => i.PlainText == "password123"));
        await SyncAll(a, b);

        Assert.Equal(new[] { "keep" }, a.Texts);
        Assert.Equal(new[] { "keep" }, b.Texts);
    }

    [Fact]
    public async Task ClearingTheHistoryClearsItEverywhereButKeepsFavourites()
    {
        var a = NewDevice();
        var b = NewDevice();
        a.App.Clipboard.Copy("one");
        a.App.Clipboard.Copy("two");
        a.App.Editing.ToggleFavourite(a.App.History.Items[0]);
        await SyncAll(a, b);

        a.App.Editing.Clear(a.App.History);
        await SyncAll(a, b);

        Assert.Empty(b.Texts);
        Assert.Equal(new[] { "two" }, b.FavouriteTexts);
    }

    [Fact]
    public async Task FavouritesAreAddedRenamedEditedAndRemovedEverywhere()
    {
        var a = NewDevice();
        var b = NewDevice();
        a.App.Clipboard.Copy("snippet");
        a.App.Editing.ToggleFavourite(a.App.History.Items[0]);
        await SyncAll(a, b);
        Assert.Equal(new[] { "snippet" }, b.FavouriteTexts);

        a.App.Editing.Rename(a.App.Favourites.Items[0], "My snippet");
        await SyncAll(a, b);
        Assert.Equal("My snippet", b.App.Favourites.Items[0].Metadata.Title);

        b.App.Editing.EditText(b.App.Favourites.Items[0], "better snippet");
        await SyncAll(a, b);
        Assert.Equal(new[] { "better snippet" }, a.FavouriteTexts);
        Assert.Equal("My snippet", a.App.Favourites.Items[0].Metadata.Title);

        a.App.Editing.ToggleFavourite(a.App.Favourites.Items[0]);
        await SyncAll(a, b);
        Assert.Empty(b.FavouriteTexts);
        Assert.DoesNotContain(server.LiveKeys, k => k.StartsWith("f/", StringComparison.Ordinal));
    }

    [Fact]
    public async Task ChangesMadeOfflineAreSentLater()
    {
        var a = NewDevice();
        var b = NewDevice();
        server.IsReachable = false;

        a.App.Clipboard.Copy("written on a plane");
        await Assert.ThrowsAsync<SyncServerException>(a.SyncAsync);
        Assert.Single(a.Sync.Pending);

        server.IsReachable = true;
        await SyncAll(a, b);

        Assert.Empty(a.Sync.Pending);
        Assert.Equal(new[] { "written on a plane" }, b.Texts);
    }

    [Fact]
    public async Task PendingChangesSurviveARestart()
    {
        var a = NewDevice();
        server.IsReachable = false;
        a.App.Clipboard.Copy("unsent");
        await Assert.ThrowsAsync<SyncServerException>(a.SyncAsync);

        // The app restarts with the same files
        var restarted = new SyncService(a.App.History, a.App.Favourites, a.App.Settings, a.Keys, a.State, server,
            new SyncFormatMapper(new FakeImageCodec()), a.App.Clock, new RecordingLogger());
        server.IsReachable = true;
        await restarted.SyncOnceAsync(TimeSpan.Zero, CancellationToken.None);

        Assert.Single(server.LiveKeys);
    }

    [Fact]
    public async Task WhatWasHereBeforeSyncIsSentOnce()
    {
        var app = new TestApp();
        app.Clipboard.Copy("old copy");
        app.Editing.ToggleFavourite(app.History.Items[0]);
        var a = new SyncDevice(server, key);
        // A device whose history already holds items when sync is turned on
        foreach (var item in app.History.Items)
        {
            a.App.History.Add(item.ReadContent()!, item.Metadata);
        }
        a.App.Favourites.Add(app.Favourites.Items[0].ReadContent()!, app.Favourites.Items[0].Metadata);
        var b = NewDevice();

        await SyncAll(a, b);
        await SyncAll(a, b);

        Assert.Equal(new[] { "old copy" }, b.Texts);
        Assert.Equal(new[] { "old copy" }, b.FavouriteTexts);
        Assert.Equal(2, server.LiveKeys.Count());
    }

    [Fact]
    public async Task CopiesFromAppsWhoseItemsExpireAreNotSynced()
    {
        var manager = new AppIdentity("KeePass.exe");
        var a = NewDevice(AppSettings.Default with { ExpiringApps = new[] { manager } });
        var b = NewDevice();

        a.App.Clipboard.Copy("secret", manager);
        a.App.Clipboard.Copy("public");
        await SyncAll(a, b);

        Assert.Equal(new[] { "public" }, b.Texts);
    }

    [Fact]
    public async Task NothingIsQueuedWhileSyncIsOff()
    {
        var a = NewDevice();
        a.Sync.TurnOff();

        a.App.Clipboard.Copy("local only");

        Assert.False(a.Sync.IsEnabled);
        Assert.Empty(a.Sync.Pending);
        await a.SyncAsync();
        Assert.Empty(server.Records);
    }

    [Fact]
    public async Task ADeviceWithAnotherKeyCantReadTheRecords()
    {
        var a = NewDevice();
        var stranger = new SyncDevice(server, SyncKey.Generate());

        a.App.Clipboard.Copy("private");
        await SyncAll(a, stranger);

        Assert.Empty(stranger.Texts);
    }

    [Fact]
    public async Task ARecordTheServerRefusesIsDroppedAndTheRestStillSent()
    {
        server.MaxRecordBytes = 400;
        var a = NewDevice();
        var b = NewDevice();

        a.App.Clipboard.Copy(new string('x', 2000));
        a.App.Clipboard.Copy("small");
        await SyncAll(a, b);

        Assert.Empty(a.Sync.Pending);
        Assert.Equal(new[] { "small" }, b.Texts);
    }

    [Fact]
    public async Task CopiedFilesStayOnTheirDevice()
    {
        var a = NewDevice();
        var b = NewDevice();

        a.App.Clipboard.Copy(new ClipboardContent(new[] { KeyValuePair.Create(ClipboardFormats.FileDrop, new byte[] { 1, 2 }) }));
        await SyncAll(a, b);

        Assert.Single(a.App.History.Items);
        Assert.Empty(b.App.History.Items);
        Assert.Empty(server.Records);
    }

    [Fact]
    public async Task ItemsOlderThanAFullHistoryKeepsAreSkipped()
    {
        var a = NewDevice();
        var b = NewDevice(AppSettings.Default with { MaxHistory = 1 });
        a.App.Clipboard.Copy("old");
        b.App.Clock.Now = a.App.Clock.Now + TimeSpan.FromHours(1);
        b.App.Clipboard.Copy("new");

        await SyncAll(a, b);

        Assert.Equal(new[] { "new" }, b.Texts);
    }

    [Fact]
    public async Task HistoryTheServerDroppedStaysOnTheDevices()
    {
        var a = NewDevice();
        var b = NewDevice();
        a.App.Clipboard.Copy("kept");
        await SyncAll(a, b);

        server.Evict(server.LiveKeys.Single());
        await SyncAll(a, b);

        Assert.Equal(new[] { "kept" }, b.Texts);
    }

    [Fact]
    public async Task ErasingTheServerDataForgetsTheKey()
    {
        var a = NewDevice();
        a.App.Clipboard.Copy("hello");
        await a.SyncAsync();

        await a.Sync.EraseServerDataAsync();

        Assert.Empty(server.Records);
        Assert.Null(a.Keys.Key);
        Assert.False(a.App.Settings.Current.SyncEnabled);
        Assert.Equal(new[] { "hello" }, a.Texts);
    }
}
