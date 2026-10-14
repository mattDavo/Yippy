using System.Runtime.InteropServices;
using Microsoft.Win32;
using Yippy.Domain.Settings;
using static Yippy.Platform.Windows.Native.NativeMethods;

namespace Yippy.Platform.Windows.Display;

/// <summary>Screens, window placement and the system theme. Coordinates are physical pixels (the app is per-monitor DPI aware).</summary>
public static class Screens
{
    /// <summary>The work area (without the taskbar) and scale factor of the screen the mouse is on.</summary>
    public static (ScreenRect WorkArea, double Scale) AtCursor()
    {
        GetCursorPos(out var point);
        var monitor = MonitorFromPoint(point, MONITOR_DEFAULTTONEAREST);
        var info = new MONITORINFO { Size = Marshal.SizeOf<MONITORINFO>() };
        GetMonitorInfo(monitor, ref info);
        var dpi = GetDpiForMonitor(monitor, MDT_EFFECTIVE_DPI, out var dpiX, out _) == 0 ? dpiX : 96;
        var work = info.Work;
        return (new ScreenRect(work.Left, work.Top, work.Right - work.Left, work.Bottom - work.Top), dpi / 96.0);
    }

    /// <summary>Moves and sizes a window without activating it.</summary>
    public static void SetBounds(IntPtr hwnd, ScreenRect bounds)
    {
        SetWindowPos(hwnd, IntPtr.Zero,
            (int)Math.Round(bounds.X), (int)Math.Round(bounds.Y),
            (int)Math.Round(bounds.Width), (int)Math.Round(bounds.Height),
            SWP_NOZORDER | SWP_NOACTIVATE);
    }

    /// <summary>Makes a window one that never takes focus and doesn't show in Alt+Tab, like the preview beside the panel.</summary>
    public static void MakeNonActivating(IntPtr hwnd)
    {
        var style = GetWindowLongPtr(hwnd, GWL_EXSTYLE).ToInt64();
        SetWindowLongPtr(hwnd, GWL_EXSTYLE, new IntPtr(style | WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW));
    }

    /// <summary>Whether apps should use the light theme (Settings › Personalisation › Colours).</summary>
    public static bool AppsUseLightTheme()
    {
        using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
        return key?.GetValue("AppsUseLightTheme") is not int value || value != 0;
    }
}
