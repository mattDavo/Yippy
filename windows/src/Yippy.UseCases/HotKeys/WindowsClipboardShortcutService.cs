using Yippy.Domain.Settings;
using Yippy.UseCases.Abstractions;

namespace Yippy.UseCases.HotKeys;

/// <summary>
/// Makes Win+V open Yippy instead of Windows' clipboard history, and gives it back.
/// </summary>
/// <remarks>
/// Explorer owns Win+V, so taking it over tells Explorer to leave it alone and restarts Explorer before Yippy registers it.
/// Giving it back does the reverse. Both are reversible at any time.
/// </remarks>
public sealed class WindowsClipboardShortcutService
{
    private readonly IShellClipboardShortcut shell;
    private readonly ToggleHotKeyService hotKey;

    public WindowsClipboardShortcutService(IShellClipboardShortcut shell, ToggleHotKeyService hotKey)
    {
        this.shell = shell;
        this.hotKey = hotKey;
    }

    /// <summary>Whether Windows has let go of Win+V (it then opens Yippy, unless Yippy's shortcut was changed since).</summary>
    public bool IsTakenOver => shell.IsReleased;

    /// <summary>Whether Win+V opens Yippy.</summary>
    public bool OpensYippy => IsTakenOver && hotKey.Current == HotKeyGesture.WindowsClipboard;

    /// <returns>Whether Win+V now opens Yippy.</returns>
    public async Task<bool> TakeOverAsync()
    {
        shell.Release();
        await shell.RestartShellAsync();
        return hotKey.TryChange(HotKeyGesture.WindowsClipboard);
    }

    /// <param name="replacement">Yippy's shortcut from now on, if it was Win+V.</param>
    /// <returns>False if <paramref name="replacement"/> is taken by another app; then nothing has changed.</returns>
    public async Task<bool> RestoreAsync(HotKeyGesture replacement)
    {
        // Let go of Win+V first, so Explorer can register it again when it restarts
        if (hotKey.Current == HotKeyGesture.WindowsClipboard && !hotKey.TryChange(replacement))
        {
            return false;
        }
        shell.Restore();
        await shell.RestartShellAsync();
        return true;
    }
}
