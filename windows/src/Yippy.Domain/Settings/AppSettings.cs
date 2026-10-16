using Yippy.Domain.Apps;
using Yippy.Domain.History;

namespace Yippy.Domain.Settings;

/// <summary>
/// The user's settings. Every property has a default, so settings saved by an older version still load
/// (a missing value takes its default instead of resetting everything).
/// </summary>
public sealed record AppSettings
{
    /// <summary>The choices offered for <see cref="MaxHistory"/>.</summary>
    public static IReadOnlyList<int> MaxHistoryOptions { get; } = new[] { 50, 100, 200, 500, 750, 1000, 1500 };

    public static AppSettings Default { get; } = new();

    public PanelPosition PanelPosition { get; init; } = PanelPosition.Right;

    /// <summary>
    /// The clipboard sequence number of the last change the history has dealt with, so a copy made while Yippy wasn't
    /// running is still picked up on launch, but nothing is added twice.
    /// </summary>
    public uint ClipboardSequenceNumber { get; init; }

    public HotKeyGesture ToggleHotKey { get; init; } = HotKeyGesture.DefaultToggle;

    public int MaxHistory { get; init; } = 500;

    public bool ShowsRichText { get; init; } = true;

    public bool PastesRichText { get; init; } = true;

    /// <summary>Apps whose copies are not saved to the history.</summary>
    public IReadOnlyList<AppIdentity> IgnoredApps { get; init; } = Array.Empty<AppIdentity>();

    /// <summary>Clipboard history items older than this many days are deleted. 0 keeps them forever.</summary>
    public int MaxItemAgeDays { get; init; }

    /// <summary>Items copied from these apps are deleted after a minute (see <see cref="AutoCleanPolicy"/>).</summary>
    public IReadOnlyList<AppIdentity> ExpiringApps { get; init; } = Array.Empty<AppIdentity>();

    /// <summary>Whether the text in copied images is read so search can find it.</summary>
    public bool RecognizesTextInImages { get; init; }

    /// <summary>Whether copies and favourites are synced with the user's other devices. The sync key is kept separately.</summary>
    public bool SyncEnabled { get; init; }

    /// <summary>The sync server's address, e.g. <c>https://sync.example.com</c>.</summary>
    public string? SyncServer { get; init; }

    /// <summary>The sync server's access key, if it has one.</summary>
    public string? SyncAccessKey { get; init; }

    public AutoCleanPolicy GetAutoCleanPolicy() => new(MaxItemAgeDays, ExpiringApps);

    public bool IsIgnored(AppIdentity? app) => app is not null && IgnoredApps.Contains(app);
}
