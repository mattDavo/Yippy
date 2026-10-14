using Yippy.Domain.Clipboard;
using Yippy.Domain.History;
using Yippy.UseCases.Abstractions;
using Yippy.UseCases.History;
using Yippy.UseCases.Settings;

namespace Yippy.UseCases.Capture;

/// <summary>
/// Adds each new copy to the clipboard history.
/// </summary>
/// <remarks>
/// Skips copies from ignored apps and copies marked as not to be kept (password managers), ignores changes Yippy made
/// itself (<see cref="RecordOwnChange"/>), and moves a copy that is already in the history to the top instead of adding it again.
/// </remarks>
public sealed class ClipboardCaptureService
{
    private readonly IClipboard clipboard;
    private readonly ItemHistory history;
    private readonly SettingsService settings;
    private readonly IClock clock;

    public ClipboardCaptureService(IClipboard clipboard, IClipboardMonitor monitor, ItemHistory history, SettingsService settings, IClock clock)
    {
        this.clipboard = clipboard;
        this.history = history;
        this.settings = settings;
        this.clock = clock;
        monitor.ClipboardChanged += (_, _) => Capture();
    }

    /// <summary>The sequence number of the last clipboard change the history has dealt with.</summary>
    public uint LastRecordedSequenceNumber => settings.Current.ClipboardSequenceNumber;

    /// <summary>Whether the clipboard still holds the change the history last dealt with.</summary>
    public bool IsClipboardUnchanged => clipboard.SequenceNumber == LastRecordedSequenceNumber;

    /// <summary>Remembers a change Yippy made to the clipboard, so it isn't added to the history as a new copy.</summary>
    public void RecordOwnChange(uint sequenceNumber) => Record(sequenceNumber);

    /// <summary>
    /// Treats what's on the clipboard now as dealt with, without saving it. On the first launch, so whatever happened to be
    /// copied before Yippy was installed doesn't end up in the history.
    /// </summary>
    public void IgnoreCurrentContent() => Record(clipboard.SequenceNumber);

    /// <summary>Adds what's on the clipboard to the history, unless it has been dealt with already.</summary>
    public void Capture()
    {
        var sequenceNumber = clipboard.SequenceNumber;
        if (sequenceNumber == LastRecordedSequenceNumber)
        {
            return;
        }
        if (clipboard.Read() is not { } snapshot)
        {
            // Another app has the clipboard open; the next change notification tries again
            return;
        }

        // Skip copies from ignored apps and opted-out copies, but still record them so they aren't picked up later
        if (settings.Current.IsIgnored(snapshot.Source) || ClipboardFormats.IsOptedOut(snapshot.Content))
        {
            Record(sequenceNumber);
            return;
        }
        var content = ClipboardFormats.WithoutPolicyFormats(snapshot.Content);
        if (content.IsEmpty)
        {
            Record(sequenceNumber);
            return;
        }

        var now = clock.Now;
        var existing = history.IndexOfContent(content.Hash);
        if (existing >= 0)
        {
            // Copying something already in the history brings it back to the top instead of adding it again
            var id = history.Items[existing].Id;
            history.Move(existing, 0);
            history.UpdateMetadata(id, m => m with { CopiedAt = now, Source = snapshot.Source });
        }
        else
        {
            history.Add(content, new ItemMetadata { CopiedAt = now, Source = snapshot.Source });
        }
        Record(sequenceNumber);
    }

    private void Record(uint sequenceNumber)
    {
        settings.Update(s => s with { ClipboardSequenceNumber = sequenceNumber });
    }
}
