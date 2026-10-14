using CommunityToolkit.Mvvm.ComponentModel;
using Yippy.App.Shell;
using Yippy.UseCases.Settings;

namespace Yippy.App.ViewModels.Settings;

/// <summary>A choice in a drop-down list.</summary>
public sealed record Option<T>(T Value, string Title);

/// <summary>A page of the settings window. Every change is saved straight away, as on macOS.</summary>
public abstract class SettingsPageViewModel : ObservableObject
{
    protected SettingsPageViewModel(SettingsPage page, string title, string glyph, SettingsService settings)
    {
        Page = page;
        Title = title;
        Glyph = glyph;
        Settings = settings;
        // A setting can change elsewhere too (the tray menu, the panel's Ctrl+Alt+arrows)
        settings.Changed += (_, _) => OnPropertyChanged(string.Empty);
    }

    public SettingsPage Page { get; }

    public string Title { get; }

    /// <summary>The page's icon in the navigation (Segoe Fluent Icons).</summary>
    public string Glyph { get; }

    protected SettingsService Settings { get; }
}
