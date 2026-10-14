using System.Windows;
using Microsoft.Win32;
using Yippy.Platform.Windows.Display;

namespace Yippy.App.Presentation;

/// <summary>Follows the Windows light or dark app theme, swapping the brushes the panel uses.</summary>
public sealed class ThemeManager : IDisposable
{
    private static readonly Uri LightTheme = new("pack://application:,,,/Yippy;component/Themes/Light.xaml");
    private static readonly Uri DarkTheme = new("pack://application:,,,/Yippy;component/Themes/Dark.xaml");

    private readonly ResourceDictionary resources;
    private ResourceDictionary? current;

    public ThemeManager(ResourceDictionary resources)
    {
        this.resources = resources;
        Apply();
        SystemEvents.UserPreferenceChanged += OnUserPreferenceChanged;
    }

    public void Dispose() => SystemEvents.UserPreferenceChanged -= OnUserPreferenceChanged;

    private void OnUserPreferenceChanged(object sender, UserPreferenceChangedEventArgs e)
    {
        if (e.Category == UserPreferenceCategory.General)
        {
            System.Windows.Application.Current?.Dispatcher.Invoke(Apply);
        }
    }

    private void Apply()
    {
        var theme = new ResourceDictionary { Source = Screens.AppsUseLightTheme() ? LightTheme : DarkTheme };
        if (current is not null)
        {
            resources.MergedDictionaries.Remove(current);
        }
        resources.MergedDictionaries.Add(theme);
        current = theme;
    }
}
