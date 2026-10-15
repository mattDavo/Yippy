using CommunityToolkit.Mvvm.ComponentModel;
using Yippy.App.Shell;

namespace Yippy.App.ViewModels.Settings;

/// <summary>The settings window: its pages, and which one is showing.</summary>
public sealed partial class SettingsViewModel : ObservableObject
{
    public SettingsViewModel(
        GeneralPageViewModel general,
        ShortcutPageViewModel shortcut,
        HistoryPageViewModel history,
        PrivacyPageViewModel privacy,
        AboutPageViewModel about)
    {
        Shortcut = shortcut;
        Pages = new SettingsPageViewModel[] { general, shortcut, history, privacy, about };
        selectedPage = general;
    }

    public IReadOnlyList<SettingsPageViewModel> Pages { get; }

    /// <summary>For the window's code-behind, which records new shortcuts.</summary>
    public ShortcutPageViewModel Shortcut { get; }

    [ObservableProperty]
    private SettingsPageViewModel selectedPage;

    public void Show(SettingsPage page) => SelectedPage = Pages.First(p => p.Page == page);
}
