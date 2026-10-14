using System.Text;
using static Yippy.Platform.Windows.Native.NativeMethods;

namespace Yippy.Platform.Windows.Input;

/// <summary>
/// Remembers the last window of another app that was in front, so Yippy can paste into it after its panel closes.
/// </summary>
/// <remarks>
/// Follows focus changes as they happen (a WinEvent hook), so opening the panel from the tray icon still pastes into the
/// app that was in use, not the taskbar. Create it on the UI thread.
/// </remarks>
public sealed class ForegroundWindowTracker : IDisposable
{
    /// <summary>Taskbar and tray windows, which take focus when the tray icon is clicked but are never pasted into.</summary>
    private static readonly HashSet<string> ShellClasses = new(StringComparer.Ordinal)
    {
        "Shell_TrayWnd",
        "Shell_SecondaryTrayWnd",
        "NotifyIconOverflowWindow",
        "TopLevelWindowForOverflowXamlIsland",
        "Windows.UI.Core.CoreWindow",
        "XamlExplorerHostIslandWindow",
    };

    // Kept in a field so the garbage collector doesn't free the callback while Windows still calls it
    private readonly WinEventProc callback;
    private readonly IntPtr hook;

    public ForegroundWindowTracker()
    {
        callback = OnForegroundChanged;
        hook = SetWinEventHook(EVENT_SYSTEM_FOREGROUND, EVENT_SYSTEM_FOREGROUND, IntPtr.Zero, callback, 0, 0,
            WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS);
        Remember(GetForegroundWindow());
    }

    /// <summary>The last window of another app that was in front, or zero if there is none.</summary>
    public IntPtr LastExternalWindow { get; private set; }

    /// <summary>Brings <see cref="LastExternalWindow"/> back to the front.</summary>
    /// <returns>Whether it is in front now.</returns>
    public bool ActivateLastExternalWindow()
    {
        var window = LastExternalWindow;
        if (window == IntPtr.Zero || !IsWindow(window))
        {
            return false;
        }
        if (IsIconic(window))
        {
            ShowWindow(window, SW_RESTORE);
        }
        SetForegroundWindow(window);
        return GetForegroundWindow() == window;
    }

    public void Dispose()
    {
        if (hook != IntPtr.Zero)
        {
            UnhookWinEvent(hook);
        }
    }

    private void OnForegroundChanged(IntPtr hook, uint eventType, IntPtr hwnd, int idObject, int idChild, uint thread, uint time)
    {
        Remember(hwnd);
    }

    private void Remember(IntPtr hwnd)
    {
        if (hwnd == IntPtr.Zero)
        {
            return;
        }
        GetWindowThreadProcessId(hwnd, out var processId);
        if (processId == Environment.ProcessId || ShellClasses.Contains(ClassName(hwnd)))
        {
            return;
        }
        LastExternalWindow = hwnd;
    }

    private static string ClassName(IntPtr hwnd)
    {
        var name = new StringBuilder(256);
        return GetClassName(hwnd, name, name.Capacity) > 0 ? name.ToString() : string.Empty;
    }
}
