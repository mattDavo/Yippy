using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Yippy.App.Shell;
using Yippy.Domain.History;
using Yippy.Domain.Search;
using Yippy.Domain.Settings;
using Yippy.UseCases.History;
using Yippy.UseCases.Paste;
using Yippy.UseCases.Search;

namespace Yippy.App.ViewModels;

/// <summary>
/// The history panel: the clipboard history or the favourites, filtered by the search, and everything that can be done to them.
/// </summary>
public sealed partial class PanelViewModel : ObservableObject
{
    private readonly HistoryEditingService editing;
    private readonly PasteService paste;
    private readonly SearchService search;
    private readonly IDialogService dialogs;
    private readonly IAppNavigation navigation;
    private readonly ItemContext context;
    private readonly Dictionary<Guid, ItemViewModel> viewModels = new();
    private CancellationTokenSource? searchCancellation;

    public PanelViewModel(
        HistoryEditingService editing,
        PasteService paste,
        SearchService search,
        IDialogService dialogs,
        IAppNavigation navigation,
        ItemContext context)
    {
        this.editing = editing;
        this.paste = paste;
        this.search = search;
        this.dialogs = dialogs;
        this.navigation = navigation;
        this.context = context;

        editing.ClipboardHistory.Changed += (_, change) => OnHistoryChanged(editing.ClipboardHistory, change);
        editing.Favourites.Changed += (_, change) => OnHistoryChanged(editing.Favourites, change);
        context.Settings.Changed += (_, e) =>
        {
            if (e.Old.ShowsRichText != e.Current.ShowsRichText)
            {
                // Items are drawn differently, so make them again
                viewModels.Clear();
                Refresh();
            }
        };
        UpdateFavouritesTitle();
        Refresh();
    }

    /// <summary>Asks for the panel to close, e.g. before pasting.</summary>
    public event EventHandler? CloseRequested;

    /// <summary>The history being shown.</summary>
    public ItemHistory History => IsFavouritesSelected ? editing.Favourites : editing.ClipboardHistory;

    public string SearchPlaceholder => "Search, or filter with /img /link /file @app";

    [ObservableProperty]
    private IReadOnlyList<ItemViewModel> items = Array.Empty<ItemViewModel>();

    [ObservableProperty]
    private ItemViewModel? selectedItem;

    [ObservableProperty]
    private string searchText = string.Empty;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(IsClipboardSelected))]
    private bool isFavouritesSelected;

    [ObservableProperty]
    private string countText = string.Empty;

    [ObservableProperty]
    private string favouritesTitle = "Favourites";

    [ObservableProperty]
    private bool isPreviewOpen;

    public bool IsClipboardSelected
    {
        get => !IsFavouritesSelected;
        set => IsFavouritesSelected = !value;
    }

    public bool IsEmpty => Items.Count == 0;

    public string EmptyTitle => SearchText.Length > 0
        ? "No matches"
        : IsFavouritesSelected ? "No favourites yet" : "Nothing copied yet";

    public string EmptyText => SearchText.Length > 0
        ? "Try fewer letters, or another filter: /img, /link, /file, /color or @app."
        : IsFavouritesSelected
            ? "Press the heart on an item, or Ctrl+D, to keep it here for good."
            : "Copy some text, a link, an image or files, and it shows up here.";

    /// <summary>The empty list's icon (Segoe Fluent Icons): a magnifier, a heart or a clipboard.</summary>
    public string EmptyGlyph => SearchText.Length > 0 ? "\uE721" : IsFavouritesSelected ? "\uEB51" : "\uE77F";

    partial void OnSearchTextChanged(string value) => Refresh();

    partial void OnIsFavouritesSelectedChanged(bool value)
    {
        Refresh();
        SelectedItem = Items.FirstOrDefault();
    }

    partial void OnItemsChanged(IReadOnlyList<ItemViewModel> value)
    {
        OnPropertyChanged(nameof(IsEmpty));
        OnPropertyChanged(nameof(EmptyTitle));
        OnPropertyChanged(nameof(EmptyText));
        OnPropertyChanged(nameof(EmptyGlyph));
    }

    /// <summary>Called each time the panel opens.</summary>
    public void OnShown()
    {
        foreach (var item in Items)
        {
            // "5 min ago" has moved on since the rows were drawn
            item.Refresh();
        }
        SelectedItem = Items.FirstOrDefault();
    }

    public void MoveSelection(int delta)
    {
        if (Items.Count == 0)
        {
            return;
        }
        var index = SelectedItem is null ? 0 : IndexOfItem(SelectedItem) + delta;
        SelectedItem = Items[Math.Clamp(index, 0, Items.Count - 1)];
    }

    public void SetPosition(PanelPosition position) => context.Settings.Update(s => s with { PanelPosition = position });

    /// <summary>Moves an item to where another one is shown (drag and drop).</summary>
    public void Move(ItemViewModel item, ItemViewModel target)
    {
        var to = History.IndexOf(target.Item.Id);
        if (to >= 0)
        {
            editing.Move(History, item.Item, to);
            SelectedItem = Items.FirstOrDefault(i => i.Item.Id == item.Item.Id);
        }
    }

    [RelayCommand]
    private Task Paste(ItemViewModel? item) => PasteWith(item, paste.PasteAsync);

    [RelayCommand]
    private Task PastePlainText(ItemViewModel? item) => PasteWith(item, paste.PastePlainTextAsync);

    [RelayCommand]
    private Task PasteTransformed(TransformOption? option)
    {
        return option is null || !option.IsApplicable
            ? Task.CompletedTask
            : PasteWith(option.Item, (history, item) => paste.PasteTransformedAsync(history, item, option.Transform));
    }

    /// <summary>Ctrl+0…9: pastes the item in that row.</summary>
    [RelayCommand]
    private Task PasteAt(int index) => index < Items.Count ? PasteWith(Items[index], paste.PasteAsync) : Task.CompletedTask;

    [RelayCommand]
    private void Delete(ItemViewModel? item)
    {
        item ??= SelectedItem;
        if (item is null)
        {
            return;
        }
        var index = IndexOfItem(item);
        editing.Delete(item.History, item.Item);
        // Keep the selection where it was, or on the new last item
        SelectedItem = Items.Count == 0 ? null : Items[Math.Clamp(index, 0, Items.Count - 1)];
    }

    /// <summary>Adds the item to the favourites, or removes it. In the favourites, removes it.</summary>
    [RelayCommand]
    private void ToggleFavourite(ItemViewModel? item)
    {
        item ??= SelectedItem;
        if (item is null)
        {
            return;
        }
        if (item.IsInFavourites)
        {
            Delete(item);
        }
        else
        {
            editing.ToggleFavourite(item.Item);
        }
    }

    [RelayCommand]
    private void Rename(ItemViewModel? item)
    {
        item ??= SelectedItem;
        if (item is not { CanRename: true })
        {
            return;
        }
        CloseRequested?.Invoke(this, EventArgs.Empty);
        var name = dialogs.Prompt("Rename Favourite", "The name is shown under the item and found by search.", item.Title ?? string.Empty);
        if (name is not null)
        {
            editing.Rename(item.Item, name);
        }
    }

    [RelayCommand]
    private void Edit(ItemViewModel? item)
    {
        item ??= SelectedItem;
        if (item is not { CanEdit: true } || item.Item.GetUnstyledText() is not { } text)
        {
            return;
        }
        CloseRequested?.Invoke(this, EventArgs.Empty);
        var edited = dialogs.Prompt("Edit Favourite", "Saving keeps the text only, without any styling.", text, multiline: true);
        if (edited is not null)
        {
            editing.EditText(item.Item, edited);
        }
    }

    [RelayCommand]
    private void ShowItemsFromApp(ItemViewModel? item)
    {
        if (item?.SourceName is { } name)
        {
            SearchText = SearchQuery.AppFilter(name);
        }
    }

    [RelayCommand]
    private void ShowClipboard() => IsFavouritesSelected = false;

    [RelayCommand]
    private void ShowFavourites() => IsFavouritesSelected = true;

    [RelayCommand]
    private void SwitchGroup() => IsFavouritesSelected = !IsFavouritesSelected;

    [RelayCommand]
    private void TogglePreview() => IsPreviewOpen = !IsPreviewOpen && SelectedItem is not null;

    [RelayCommand]
    private void Close() => CloseRequested?.Invoke(this, EventArgs.Empty);

    [RelayCommand]
    private void OpenSettings()
    {
        CloseRequested?.Invoke(this, EventArgs.Empty);
        navigation.ShowSettings();
    }

    [RelayCommand]
    private void ShowHelp()
    {
        CloseRequested?.Invoke(this, EventArgs.Empty);
        navigation.ShowHelp();
    }

    private async Task PasteWith(ItemViewModel? item, Func<ItemHistory, HistoryItem, Task> action)
    {
        item ??= SelectedItem;
        if (item is null)
        {
            return;
        }
        // Close first: pasting goes to the app that was in front before the panel opened
        CloseRequested?.Invoke(this, EventArgs.Empty);
        await action(item.History, item.Item);
    }

    private int IndexOfItem(ItemViewModel item)
    {
        for (var i = 0; i < Items.Count; i++)
        {
            if (Items[i] == item)
            {
                return i;
            }
        }
        return -1;
    }

    private void OnHistoryChanged(ItemHistory history, HistoryChange change)
    {
        if (history == editing.Favourites)
        {
            UpdateFavouritesTitle();
        }
        if (change is HistoryChange.Updated { Item: var updated } && viewModels.TryGetValue(updated.Id, out var viewModel))
        {
            viewModel.Refresh();
        }
        if (history == History)
        {
            Refresh();
        }
        else if (history == editing.Favourites)
        {
            // The hearts in the clipboard list may have changed
            foreach (var item in Items)
            {
                item.RefreshFavourite();
            }
        }
    }

    private void UpdateFavouritesTitle()
    {
        var count = editing.Favourites.Items.Count;
        FavouritesTitle = count == 0 ? "Favourites" : $"Favourites ({count})";
    }

    /// <summary>Shows the selected history's items, filtered by the search if there is one.</summary>
    private void Refresh()
    {
        searchCancellation?.Cancel();
        if (SearchText.Trim().Length == 0)
        {
            Show(History, History.Items, isSearchResult: false);
            return;
        }
        _ = RunSearchAsync(History, SearchText);
    }

    private async Task RunSearchAsync(ItemHistory history, string query)
    {
        var cancellation = new CancellationTokenSource();
        searchCancellation = cancellation;
        try
        {
            var matches = await search.SearchAsync(query, history.Items, cancellation.Token);
            if (!cancellation.IsCancellationRequested && history == History)
            {
                Show(history, matches, isSearchResult: true);
            }
        }
        catch (OperationCanceledException)
        {
            // A newer search replaced it
        }
    }

    private void Show(ItemHistory history, IReadOnlyList<HistoryItem> historyItems, bool isSearchResult)
    {
        var selectedId = SelectedItem?.Item.Id;
        var selectedIndex = SelectedItem is null ? 0 : Math.Max(0, IndexOfItem(SelectedItem));

        var shown = new List<ItemViewModel>(historyItems.Count);
        foreach (var item in historyItems)
        {
            if (!viewModels.TryGetValue(item.Id, out var viewModel) || viewModel.History != history)
            {
                viewModel = new ItemViewModel(item, history, this, context);
                viewModels[item.Id] = viewModel;
            }
            viewModel.Index = shown.Count;
            shown.Add(viewModel);
        }
        // Forget view models of items that are gone, so their images can be freed
        if (viewModels.Count > shown.Count + editing.ClipboardHistory.Items.Count + editing.Favourites.Items.Count)
        {
            var current = editing.ClipboardHistory.Items.Concat(editing.Favourites.Items).Select(i => i.Id).ToHashSet();
            foreach (var id in viewModels.Keys.Where(id => !current.Contains(id)).ToList())
            {
                viewModels.Remove(id);
            }
        }

        Items = shown;
        CountText = isSearchResult
            ? shown.Count == 1 ? "1 match" : $"{shown.Count} matches"
            : shown.Count == 1 ? "1 item" : $"{shown.Count} items";
        SelectedItem = shown.FirstOrDefault(i => i.Item.Id == selectedId)
            ?? (shown.Count == 0 ? null : shown[Math.Min(selectedIndex, shown.Count - 1)]);
    }
}
