using Yippy.Domain.Settings;
using Yippy.UseCases.Abstractions;
using Yippy.UseCases.Settings;

namespace Yippy.UseCases.HotKeys;

/// <summary>
/// Hands Win+V to Yippy or back to Windows without Yippy running: the installer's and uninstaller's side of
/// <see cref="WindowsClipboardShortcutService"/>. It only changes settings; Yippy registers the shortcut when it starts.
/// </summary>
/// <remarks>
/// Before Yippy's first launch there are no settings yet, and their absence is what tells Yippy it is starting for the
/// first time. So the setup leaves them alone then, and <see cref="ApplyToFirstLaunch"/> picks the shortcut up instead.
/// </remarks>
public sealed class WindowsClipboardShortcutSetup
{
    private readonly IShellClipboardShortcut shell;
    private readonly SettingsService settings;

    public WindowsClipboardShortcutSetup(IShellClipboardShortcut shell, SettingsService settings)
    {
        this.shell = shell;
        this.settings = settings;
    }

    /// <summary>Makes Win+V open Yippy.</summary>
    /// <param name="restartShell">Restart Explorer so the change takes effect now, not at the next sign-in.</param>
    public async Task UseWinVAsync(bool restartShell)
    {
        var wasReleased = shell.IsReleased;
        shell.Release();
        if (!settings.IsFirstLaunch)
        {
            settings.Update(s => s with { ToggleHotKey = HotKeyGesture.WindowsClipboard });
        }
        if (!wasReleased && restartShell)
        {
            await shell.RestartShellAsync();
        }
    }

    /// <summary>
    /// Gives Win+V back to Windows' clipboard history, and sets Yippy's shortcut back to
    /// <see cref="HotKeyGesture.DefaultToggle"/> if it was Win+V. Does nothing if Windows already has it.
    /// </summary>
    /// <param name="restartShell">Restart Explorer so the change takes effect now, not at the next sign-in.</param>
    public async Task RestoreAsync(bool restartShell)
    {
        if (!settings.IsFirstLaunch)
        {
            settings.Update(s => s.ToggleHotKey == HotKeyGesture.WindowsClipboard ? s with { ToggleHotKey = HotKeyGesture.DefaultToggle } : s);
        }
        if (!shell.IsReleased)
        {
            return;
        }
        shell.Restore();
        if (restartShell)
        {
            await shell.RestartShellAsync();
        }
    }

    /// <summary>
    /// On Yippy's first launch, makes Win+V its shortcut if Windows already let go of it (the installer offers that).
    /// Call it before the shortcut is registered.
    /// </summary>
    public void ApplyToFirstLaunch()
    {
        if (settings.IsFirstLaunch && shell.IsReleased)
        {
            settings.Update(s => s with { ToggleHotKey = HotKeyGesture.WindowsClipboard });
        }
    }
}
