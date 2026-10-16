using Yippy.Domain.Clipboard;
using Yippy.Domain.History;
using Yippy.UseCases.Abstractions;
using Yippy.UseCases.Capture;

namespace Yippy.UseCases.History;

/// <summary>
/// The changes the user makes to the histories from the panel: deleting, reordering, favouriting, renaming and editing.
/// </summary>
/// <remarks>
/// Keeps the clipboard in step with the clipboard history, whose top item is what's on the clipboard.
/// </remarks>
public sealed class HistoryEditingService
{
    private readonly IClipboard clipboard;
    private readonly ClipboardCaptureService capture;
    private readonly IHistoryActivity activity;

    public HistoryEditingService(ItemHistory clipboardHistory, ItemHistory favourites, IClipboard clipboard, ClipboardCaptureService capture,
        IHistoryActivity? activity = null)
    {
        ClipboardHistory = clipboardHistory;
        Favourites = favourites;
        this.clipboard = clipboard;
        this.capture = capture;
        this.activity = activity ?? NoHistoryActivity.Instance;
    }

    public ItemHistory ClipboardHistory { get; }

    public ItemHistory Favourites { get; }

    /// <summary>Deletes the item. Deleting the clipboard history's top item also clears it from the clipboard.</summary>
    public void Delete(ItemHistory history, HistoryItem item)
    {
        var index = history.IndexOf(item.Id);
        if (index < 0)
        {
            return;
        }
        var wasOnClipboard = index == 0 && history.MovesPastedItemToTop && capture.IsClipboardUnchanged;
        // Before deleting, while the item's content can still be read
        activity.Deleted(history, new[] { item });
        history.Delete(item.Id);
        if (wasOnClipboard)
        {
            capture.RecordOwnChange(clipboard.Clear());
        }
    }

    public void Clear(ItemHistory history)
    {
        var hadClipboard = history.MovesPastedItemToTop && history.Items.Count > 0 && capture.IsClipboardUnchanged;
        history.Clear();
        activity.Cleared(history);
        if (hadClipboard)
        {
            capture.RecordOwnChange(clipboard.Clear());
        }
    }

    /// <summary>Moves an item. Moving one to the top of the clipboard history puts it on the clipboard.</summary>
    public void Move(ItemHistory history, HistoryItem item, int to)
    {
        var from = history.IndexOf(item.Id);
        if (from < 0 || from == to)
        {
            return;
        }
        history.Move(from, to);
        if (to == 0 && history.MovesPastedItemToTop && item.ReadContent() is { } content)
        {
            capture.RecordOwnChange(clipboard.Write(content));
        }
    }

    public bool IsFavourite(HistoryItem item) => Favourites.ContainsContent(item.ContentHash);

    /// <summary>
    /// Adds a copy of a clipboard item to the top of the favourites, or removes the copy if it's already there.
    /// Favourites hold their own copy, so clearing or trimming the clipboard history never removes one.
    /// </summary>
    /// <returns>Whether the item is now a favourite.</returns>
    public bool ToggleFavourite(HistoryItem item)
    {
        var index = Favourites.IndexOfContent(item.ContentHash);
        if (index >= 0)
        {
            var favourite = Favourites.Items[index];
            activity.Deleted(Favourites, new[] { favourite });
            Favourites.Delete(favourite.Id);
            return false;
        }
        if (item.ReadContent() is not { } content)
        {
            return false;
        }
        // Keep where and when it was copied, and any text read from its image
        activity.FavouriteChanged(Favourites.Add(content, item.Metadata));
        return true;
    }

    /// <summary>Names a favourite. The name is shown under it and found by search. An empty name removes it.</summary>
    public void Rename(HistoryItem favourite, string name)
    {
        var title = name.Trim();
        Favourites.UpdateMetadata(favourite.Id, m => m with { Title = title.Length == 0 ? null : title });
        if (Favourites.IndexOf(favourite.Id) is var index and >= 0)
        {
            activity.FavouriteChanged(Favourites.Items[index]);
        }
    }

    /// <summary>Replaces a favourite's content with plain text, without any styling it had.</summary>
    public void EditText(HistoryItem favourite, string text)
    {
        if (text.Length == 0 || text == favourite.GetUnstyledText())
        {
            return;
        }
        if (Favourites.Replace(favourite.Id, ClipboardContent.FromText(text)) is { } edited)
        {
            activity.FavouriteChanged(edited, replaced: favourite);
        }
    }
}
