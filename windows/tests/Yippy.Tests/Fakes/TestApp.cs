using Yippy.Domain.Settings;
using Yippy.UseCases.Capture;
using Yippy.UseCases.History;
using Yippy.UseCases.Paste;
using Yippy.UseCases.Settings;

namespace Yippy.Tests.Fakes;

/// <summary>The use cases wired together over fakes, like the app's composition root does over the real adapters.</summary>
public sealed class TestApp
{
    public TestApp(AppSettings? settings = null, InMemoryHistoryRepository? historyRepository = null)
    {
        HistoryRepository = historyRepository ?? new InMemoryHistoryRepository();
        Settings = new SettingsService(new InMemorySettingsRepository(settings ?? AppSettings.Default));
        History = new ItemHistory(HistoryRepository, HistoryRepository, Settings.Current.MaxHistory, movesPastedItemToTop: true);
        Favourites = new ItemHistory(FavouritesRepository, FavouritesRepository, int.MaxValue, movesPastedItemToTop: false);
        Capture = new ClipboardCaptureService(Clipboard, Clipboard, History, Settings, Clock);
        Paste = new PasteService(Clipboard, Simulator, Capture, Settings);
        Editing = new HistoryEditingService(History, Favourites, Clipboard, Capture);
        _ = new HistorySettingsSync(Settings, History);
    }

    public FakeClipboard Clipboard { get; } = new();

    public FakeClock Clock { get; } = new();

    public FakePasteSimulator Simulator { get; } = new();

    public InMemoryHistoryRepository HistoryRepository { get; }

    public InMemoryHistoryRepository FavouritesRepository { get; } = new();

    public SettingsService Settings { get; }

    public ItemHistory History { get; }

    public ItemHistory Favourites { get; }

    public ClipboardCaptureService Capture { get; }

    public PasteService Paste { get; }

    public HistoryEditingService Editing { get; }

    public IReadOnlyList<string?> Texts => History.Items.Select(i => i.PlainText).ToList();
}
