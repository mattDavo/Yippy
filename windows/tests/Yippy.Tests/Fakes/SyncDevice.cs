using Yippy.Domain.Settings;
using Yippy.Domain.Sync;
using Yippy.UseCases.Sync;

namespace Yippy.Tests.Fakes;

/// <summary>A device with Yippy and sync turned on, sharing a server and sync key with the other devices of a test.</summary>
public sealed class SyncDevice
{
    public static readonly Uri ServerAddress = new("https://sync.example.com");

    public SyncDevice(FakeSyncServer server, SyncKey key, AppSettings? settings = null, InMemorySyncStateRepository? state = null)
    {
        App = new TestApp((settings ?? AppSettings.Default) with { SyncEnabled = true, SyncServer = ServerAddress.ToString() },
            activity: () => Sync!);
        Keys = new InMemorySyncKeyStore(key);
        State = state ?? new InMemorySyncStateRepository();
        Sync = new SyncService(App.History, App.Favourites, App.Settings, Keys, State, server, new SyncFormatMapper(new FakeImageCodec()),
            App.Clock, new RecordingLogger());
    }

    public TestApp App { get; }

    public SyncService Sync { get; }

    public InMemorySyncKeyStore Keys { get; }

    public InMemorySyncStateRepository State { get; }

    public IReadOnlyList<string?> Texts => App.Texts;

    public IReadOnlyList<string?> FavouriteTexts => App.Favourites.Items.Select(i => i.PlainText).ToList();

    public Task SyncAsync() => Sync.SyncOnceAsync(TimeSpan.Zero, CancellationToken.None);
}
