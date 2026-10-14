using Yippy.Domain.Clipboard;
using Yippy.Domain.History;
using Yippy.Domain.Transforms;
using Yippy.UseCases.Abstractions;
using Yippy.UseCases.Capture;
using Yippy.UseCases.History;
using Yippy.UseCases.Settings;

namespace Yippy.UseCases.Paste;

/// <summary>Puts an item on the clipboard and pastes it into the app that was in front.</summary>
public sealed class PasteService
{
    private readonly IClipboard clipboard;
    private readonly IPasteSimulator simulator;
    private readonly ClipboardCaptureService capture;
    private readonly SettingsService settings;

    public PasteService(IClipboard clipboard, IPasteSimulator simulator, ClipboardCaptureService capture, SettingsService settings)
    {
        this.clipboard = clipboard;
        this.simulator = simulator;
        this.capture = capture;
        this.settings = settings;
    }

    /// <summary>Pastes the item as it was copied (without its styling when pasting rich text is turned off).</summary>
    public Task PasteAsync(ItemHistory history, HistoryItem item)
    {
        if (item.ReadContent() is not { } content)
        {
            return Task.CompletedTask;
        }
        if (!settings.Current.PastesRichText && item.PlainText is not null)
        {
            content = content.Without(ClipboardFormats.RichTextFormats.Contains);
        }
        return PasteAsync(history, item, content);
    }

    /// <summary>Pastes only the item's text, without styling. Items without text are pasted as they are.</summary>
    public Task PastePlainTextAsync(ItemHistory history, HistoryItem item)
    {
        return item.GetUnstyledText() is { } text
            ? PasteAsync(history, item, ClipboardContent.FromText(text))
            : PasteAsync(history, item);
    }

    /// <summary>Pastes the item's text changed by <paramref name="transform"/>, if it applies to it.</summary>
    public Task PasteTransformedAsync(ItemHistory history, HistoryItem item, ITextTransform transform)
    {
        return item.GetUnstyledText() is { } text && transform.Apply(text) is { } transformed
            ? PasteAsync(history, item, ClipboardContent.FromText(transformed))
            : Task.CompletedTask;
    }

    /// <summary>Pastes <paramref name="content"/> in place of the item, which still moves to the top like any paste.</summary>
    private Task PasteAsync(ItemHistory history, HistoryItem item, ClipboardContent content)
    {
        if (history.MovesPastedItemToTop)
        {
            var index = history.IndexOf(item.Id);
            if (index > 0)
            {
                history.Move(index, 0);
            }
            // The history already has this copy, so the change must not come back as a new one
            capture.RecordOwnChange(clipboard.Write(content));
        }
        else
        {
            // Favourites: leave the change for the clipboard history to pick up like any other copy
            clipboard.Write(content);
        }
        return simulator.PasteAsync();
    }
}
