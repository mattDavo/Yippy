using static Yippy.Platform.Windows.Native.NativeMethods;

namespace Yippy.Platform.Windows.Display;

/// <summary>The window frame Windows draws (DWM): title bar theme, rounded corners and border colour.</summary>
public static class WindowFrame
{
    private const int DWMWA_USE_IMMERSIVE_DARK_MODE = 20;
    private const int DWMWA_WINDOW_CORNER_PREFERENCE = 33;
    private const int DWMWA_BORDER_COLOR = 34;
    private const int DWMWCP_ROUND = 2;

    /// <summary>Gives a window a dark or light title bar (Windows 10 20H1 and later; ignored before).</summary>
    public static void SetDarkTitleBar(IntPtr hwnd, bool dark)
    {
        var value = dark ? 1 : 0;
        _ = DwmSetWindowAttribute(hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, ref value, sizeof(int));
    }

    /// <summary>Rounds a window's corners, as Windows 11 does for its own windows.</summary>
    /// <returns>False before Windows 11, which has square corners and draws no border.</returns>
    public static bool RoundCorners(IntPtr hwnd)
    {
        var value = DWMWCP_ROUND;
        return DwmSetWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, ref value, sizeof(int)) == 0;
    }

    /// <summary>The colour of the 1-pixel border Windows 11 draws around a window.</summary>
    public static void SetBorderColor(IntPtr hwnd, byte red, byte green, byte blue)
    {
        // COLORREF is 0x00BBGGRR
        var value = red | (green << 8) | (blue << 16);
        _ = DwmSetWindowAttribute(hwnd, DWMWA_BORDER_COLOR, ref value, sizeof(int));
    }
}
