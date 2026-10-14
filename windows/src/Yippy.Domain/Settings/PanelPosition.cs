namespace Yippy.Domain.Settings;

/// <summary>Where the history panel sits on the screen. The values match the macOS app's.</summary>
public enum PanelPosition
{
    Right = 0,
    Left = 1,
    Top = 2,
    Bottom = 3,
    CenterSmall = 4,
    CenterMedium = 5,
    CenterLarge = 6,
    FullScreen = 7,
    CenterExtraSmall = 8,
}

public static class PanelPositions
{
    /// <summary>Every position, in menu order.</summary>
    public static IReadOnlyList<PanelPosition> All { get; } = new[]
    {
        PanelPosition.Right,
        PanelPosition.Left,
        PanelPosition.Top,
        PanelPosition.Bottom,
        PanelPosition.CenterExtraSmall,
        PanelPosition.CenterSmall,
        PanelPosition.CenterMedium,
        PanelPosition.CenterLarge,
        PanelPosition.FullScreen,
    };

    public static string Title(this PanelPosition position) => position switch
    {
        PanelPosition.Right => "Right",
        PanelPosition.Left => "Left",
        PanelPosition.Top => "Top",
        PanelPosition.Bottom => "Bottom",
        PanelPosition.CenterExtraSmall => "Center (Extra Small)",
        PanelPosition.CenterSmall => "Center (Small)",
        PanelPosition.CenterMedium => "Center (Medium)",
        PanelPosition.CenterLarge => "Center (Large)",
        PanelPosition.FullScreen => "Full Screen",
        _ => position.ToString(),
    };
}
