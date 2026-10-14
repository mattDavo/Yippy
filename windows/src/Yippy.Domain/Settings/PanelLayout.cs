namespace Yippy.Domain.Settings;

/// <summary>A rectangle in screen pixels.</summary>
public readonly record struct ScreenRect(double X, double Y, double Width, double Height)
{
    public double Right => X + Width;

    public double Bottom => Y + Height;
}

/// <summary>Works out the panel's frame for a position on a screen.</summary>
public static class PanelLayout
{
    /// <summary>Width of the panel when it sits at the left or right edge, in device-independent pixels.</summary>
    public const double SideWidth = 400;

    /// <summary>Height of the panel when it sits at the top or bottom edge, in device-independent pixels.</summary>
    public const double EdgeHeight = 300;

    /// <param name="workArea">The screen's work area (without the taskbar), in pixels.</param>
    /// <param name="scale">The screen's scale factor, e.g. 1.5 at 144 DPI.</param>
    public static ScreenRect GetFrame(PanelPosition position, ScreenRect workArea, double scale)
    {
        var width = Math.Min(SideWidth * scale, workArea.Width);
        var height = Math.Min(EdgeHeight * scale, workArea.Height);
        return position switch
        {
            PanelPosition.Right => workArea with { X = workArea.Right - width, Width = width },
            PanelPosition.Left => workArea with { Width = width },
            PanelPosition.Top => workArea with { Height = height },
            PanelPosition.Bottom => workArea with { Y = workArea.Bottom - height, Height = height },
            PanelPosition.CenterExtraSmall => Centered(workArea, 1.0 / 3),
            PanelPosition.CenterSmall => Centered(workArea, 0.5),
            PanelPosition.CenterMedium => Centered(workArea, 0.7),
            PanelPosition.CenterLarge => Centered(workArea, 0.85),
            PanelPosition.FullScreen => workArea,
            _ => workArea,
        };
    }

    private static ScreenRect Centered(ScreenRect area, double fraction)
    {
        var width = area.Width * fraction;
        var height = area.Height * fraction;
        return new ScreenRect(area.X + (area.Width - width) / 2, area.Y + (area.Height - height) / 2, width, height);
    }
}
