using Yippy.UseCases.Abstractions;
using Yippy.UseCases.Capture;
using Yippy.UseCases.History;
using Yippy.UseCases.Settings;

namespace Yippy.UseCases.Cleaning;

/// <summary>
/// Deletes the clipboard history items the <see cref="Domain.History.AutoCleanPolicy"/> says have expired. Favourites are never cleaned.
/// </summary>
/// <remarks>The app calls <see cref="Clean"/> every few seconds; it also runs whenever the cleaning settings change.</remarks>
public sealed class AutoCleanService
{
    /// <summary>How often the app should call <see cref="Clean"/>.</summary>
    public static readonly TimeSpan Interval = TimeSpan.FromSeconds(10);

    private readonly ItemHistory history;
    private readonly IClipboard clipboard;
    private readonly ClipboardCaptureService capture;
    private readonly SettingsService settings;
    private readonly IClock clock;

    public AutoCleanService(ItemHistory history, IClipboard clipboard, ClipboardCaptureService capture, SettingsService settings, IClock clock)
    {
        this.history = history;
        this.clipboard = clipboard;
        this.capture = capture;
        this.settings = settings;
        this.clock = clock;
        settings.Changed += (_, e) =>
        {
            if (e.Old.MaxItemAgeDays != e.Current.MaxItemAgeDays || !e.Old.ExpiringApps.SequenceEqual(e.Current.ExpiringApps))
            {
                Clean();
            }
        };
    }

    public void Clean()
    {
        var policy = settings.Current.GetAutoCleanPolicy();
        if (!policy.IsActive)
        {
            return;
        }
        var now = clock.Now;
        // The top item is what's on the clipboard, unless something has been copied since that the history ignored
        var top = capture.IsClipboardUnchanged ? history.Items.FirstOrDefault() : null;
        var deleted = history.DeleteWhere(i => policy.IsExpired(i.Metadata, now));
        if (top is not null && deleted.Contains(top))
        {
            // Don't leave it on the clipboard either
            capture.RecordOwnChange(clipboard.Clear());
        }
    }
}
