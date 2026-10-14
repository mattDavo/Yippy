using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Yippy.App.Shell;
using Yippy.Domain.Settings;
using Yippy.UseCases.Abstractions;
using Yippy.UseCases.HotKeys;
using Yippy.UseCases.Settings;

namespace Yippy.App.ViewModels.Settings;

/// <summary>The shortcut that opens Yippy, and handing Win+V over from Windows' clipboard history.</summary>
public sealed partial class ShortcutPageViewModel : SettingsPageViewModel
{
    private const string RecordingMessage = "Press the new shortcut. Esc cancels.";

    private readonly ToggleHotKeyService hotKey;
    private readonly WindowsClipboardShortcutService windowsClipboardShortcut;
    private readonly IClipboardShortcutScripts scripts;
    private readonly IDialogService dialogs;
    private readonly ILauncher launcher;
    private readonly IAppNavigation navigation;

    public ShortcutPageViewModel(
        SettingsService settings,
        ToggleHotKeyService hotKey,
        WindowsClipboardShortcutService windowsClipboardShortcut,
        IClipboardShortcutScripts scripts,
        IDialogService dialogs,
        ILauncher launcher,
        IAppNavigation navigation)
        : base(SettingsPage.Shortcut, "Shortcut", "", settings)
    {
        this.hotKey = hotKey;
        this.windowsClipboardShortcut = windowsClipboardShortcut;
        this.scripts = scripts;
        this.dialogs = dialogs;
        this.launcher = launcher;
        this.navigation = navigation;
    }

    public string HotKeyText => Settings.Current.ToggleHotKey.ToString();

    /// <summary>Why the last shortcut wasn't taken, or how to type one.</summary>
    [ObservableProperty]
    private string? hotKeyMessage;

    /// <summary>While a new shortcut is typed, the current one must not open the panel.</summary>
    public void BeginRecordingHotKey()
    {
        hotKey.Suspend();
        HotKeyMessage = RecordingMessage;
    }

    public void EndRecordingHotKey()
    {
        hotKey.Resume();
        if (HotKeyMessage == RecordingMessage)
        {
            HotKeyMessage = null;
        }
    }

    public void SetHotKey(HotKeyGesture gesture)
    {
        if (!gesture.IsValid)
        {
            HotKeyMessage = "Add Ctrl, Alt, Shift or Win, so typing in other apps isn't taken over.";
        }
        else if (hotKey.TryChange(gesture))
        {
            HotKeyMessage = null;
        }
        else
        {
            HotKeyMessage = $"Another app uses {gesture}. Try another shortcut.";
        }
        OnPropertyChanged(nameof(HotKeyText));
        OnPropertyChanged(nameof(WinVNote));
    }

    [RelayCommand]
    private void ResetHotKey() => SetHotKey(HotKeyGesture.DefaultToggle);

    /// <summary>Whether Windows has let go of Win+V for Yippy.</summary>
    public bool IsWinVTakenOver => windowsClipboardShortcut.IsTakenOver;

    public string WinVButtonText => IsWinVTakenOver ? "Give Win+V back" : "Use Win+V";

    public string WinVNote => !IsWinVTakenOver
        ? "Win+V opens Windows' clipboard history. Yippy can take it over, and you can give it back at any time."
        : windowsClipboardShortcut.OpensYippy
            ? $"Win+V opens Yippy. Giving it back to Windows makes Yippy's shortcut {HotKeyGesture.DefaultToggle}."
            : $"Windows leaves Win+V alone, but Yippy opens with {HotKeyText}. Give Win+V back to use Windows' clipboard history again.";

    /// <summary>Takes Win+V over from Windows' clipboard history, or gives it back.</summary>
    [RelayCommand]
    private async Task ToggleWinV()
    {
        var takeOver = !IsWinVTakenOver;
        var message = (takeOver
                ? "Win+V will open Yippy instead of Windows' clipboard history."
                : windowsClipboardShortcut.OpensYippy
                    ? $"Win+V will open Windows' clipboard history again, and Yippy will open with {HotKeyGesture.DefaultToggle}."
                    : "Win+V will open Windows' clipboard history again.")
            + "\n\nTo apply it, Windows Explorer restarts: the taskbar disappears for a moment and open File Explorer "
            + "windows close. You can change it back here at any time.";
        if (!dialogs.Confirm(takeOver ? "Use Win+V for Yippy" : "Give Win+V Back to Windows", message))
        {
            return;
        }
        if (takeOver)
        {
            HotKeyMessage = await windowsClipboardShortcut.TakeOverAsync()
                ? null
                : "Windows still holds Win+V. Sign out and back in, then try again.";
        }
        else
        {
            HotKeyMessage = await windowsClipboardShortcut.RestoreAsync(HotKeyGesture.DefaultToggle)
                ? null
                : $"Another app uses {HotKeyGesture.DefaultToggle}. Choose another shortcut above, then try again.";
        }
        OnPropertyChanged(string.Empty);
    }

    public string ScriptsNote => $"{string.Join(" and ", scripts.FileNames)} make the same change without Yippy, "
        + "for example for another account. Yippy.exe --use-win-v and --restore-win-v do too.";

    /// <summary>Where the scripts were saved, after saving them.</summary>
    [ObservableProperty]
    private string? scriptsMessage;

    [RelayCommand]
    private void SaveScripts()
    {
        if (dialogs.PickFolder("Choose where to save the Win+V scripts") is not { } folder)
        {
            return;
        }
        try
        {
            scripts.SaveTo(folder);
            ScriptsMessage = $"Saved to {folder}";
            launcher.Open(folder);
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException)
        {
            ScriptsMessage = $"Couldn't save the scripts there: {e.Message}";
        }
    }

    [RelayCommand]
    private void ShowShortcuts() => navigation.ShowHelp();
}
