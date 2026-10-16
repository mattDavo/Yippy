using Yippy.Domain.History;
using Yippy.Domain.Settings;
using Yippy.UseCases.Capture;
using Yippy.UseCases.History;
using Yippy.UseCases.Paste;
using Yippy.UseCases.Settings;

namespace Yippy.Tests.Fakes;

/// <summary>The use cases wired together over fakes, like the app's composition root does over the real adapters.</summary>
public sealed class TestApp
{
    /// <param name="activity">Gets what hears about the user's activity, e.g. sync, once it exists.</param>
    public TestApp(AppSettings? settings = null, InMemoryHistoryRepository? historyRepository = null, Func<IHistoryActivity>? activity = null)
    {
        var forwarded = activity is null ? null : new ForwardedActivity(activity);
        HistoryRepository = historyRepository ?? new InMemoryHistoryRepository();
        Settings = new SettingsService(new InMemorySettingsRepository(settings ?? AppSettings.Default));
        History = new ItemHistory(HistoryRepository, HistoryRepository, Settings.Current.MaxHistory, movesPastedItemToTop: true);
        Favourites = new ItemHistory(FavouritesRepository, FavouritesRepository, int.MaxValue, movesPastedItemToTop: false);
        Capture = new ClipboardCaptureService(Clipboard, Clipboard, History, Settings, Clock, forwarded);
        Paste = new PasteService(Clipboard, Simulator, Capture, Settings);
        Editing = new HistoryEditingService(History, Favourites, Clipboard, Capture, forwarded);
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

    /// <summary>Passes the activity on to whatever <c>target</c> returns at the time.</summary>
    private sealed class ForwardedActivity : IHistoryActivity
    {
        private readonly Func<IHistoryActivity> target;

        public ForwardedActivity(Func<IHistoryActivity> target) => this.target = target;

        public void Copied(HistoryItem item) => target().Copied(item);

        public void Deleted(ItemHistory history, IReadOnlyList<HistoryItem> items) => target().Deleted(history, items);

        public void Cleared(ItemHistory history) => target().Cleared(history);

        public void FavouriteChanged(HistoryItem favourite, HistoryItem? replaced = null) => target().FavouriteChanged(favourite, replaced);
    }
}
