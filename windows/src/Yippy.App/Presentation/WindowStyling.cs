using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;
using Microsoft.Win32;
using Yippy.Platform.Windows.Display;

namespace Yippy.App.Presentation;

/// <summary>
/// Makes a window's frame match the app theme: a dark title bar in the dark theme, and on Windows 11 rounded corners
/// with the frame's border drawn by Windows. Set <c>presentation:WindowStyling.FollowsTheme="True"</c> on the window.
/// </summary>
/// <remarks>
/// <c>Yippy.FrameThickness</c> (1 in Themes/Fluent.xaml) is the width of the border a borderless window draws itself.
/// Where Windows draws the border, it becomes 0 in that window's resources, so the window doesn't get two.
/// </remarks>
public static class WindowStyling
{
    public const string FrameThicknessKey = "Yippy.FrameThickness";

    public static readonly DependencyProperty FollowsThemeProperty = DependencyProperty.RegisterAttached(
        "FollowsTheme", typeof(bool), typeof(WindowStyling), new PropertyMetadata(false, OnFollowsThemeChanged));

    public static bool GetFollowsTheme(Window window) => (bool)window.GetValue(FollowsThemeProperty);

    public static void SetFollowsTheme(Window window, bool value) => window.SetValue(FollowsThemeProperty, value);

    private static void OnFollowsThemeChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        if (d is not Window window || e.NewValue is not true)
        {
            return;
        }
        UserPreferenceChangedEventHandler onPreferenceChanged = (_, args) =>
        {
            if (args.Category == UserPreferenceCategory.General)
            {
                // After ThemeManager has swapped the brushes
                window.Dispatcher.BeginInvoke(() => Apply(window), System.Windows.Threading.DispatcherPriority.Background);
            }
        };
        window.SourceInitialized += (_, _) =>
        {
            Apply(window);
            SystemEvents.UserPreferenceChanged += onPreferenceChanged;
        };
        window.Closed += (_, _) => SystemEvents.UserPreferenceChanged -= onPreferenceChanged;
    }

    private static void Apply(Window window)
    {
        var hwnd = new WindowInteropHelper(window).Handle;
        if (hwnd == IntPtr.Zero)
        {
            return;
        }
        WindowFrame.SetDarkTitleBar(hwnd, !Screens.AppsUseLightTheme());
        if (window.WindowStyle == WindowStyle.None && WindowFrame.RoundCorners(hwnd))
        {
            var border = window.TryFindResource("Yippy.PanelBorder") is SolidColorBrush brush ? brush.Color : Colors.Gray;
            WindowFrame.SetBorderColor(hwnd, border.R, border.G, border.B);
            window.Resources[FrameThicknessKey] = new Thickness(0);
        }
    }
}
