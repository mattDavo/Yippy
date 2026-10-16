using System.Reflection;
using CommunityToolkit.Mvvm.Input;
using Yippy.App.Shell;
using Yippy.UseCases.Settings;

namespace Yippy.App.ViewModels.Settings;

/// <summary>The version, and where to find help or report a problem.</summary>
public sealed partial class AboutPageViewModel : SettingsPageViewModel
{
    public const string Website = Brand.Repository;

    private readonly ILauncher launcher;
    private readonly IAppNavigation navigation;

    public AboutPageViewModel(SettingsService settings, ILauncher launcher, IAppNavigation navigation)
        : base(SettingsPage.About, "About", "", settings)
    {
        this.launcher = launcher;
        this.navigation = navigation;
    }

    public string Version { get; } = Assembly.GetEntryAssembly()?.GetName().Version is { } version
        ? $"Version {version.ToString(3)}"
        : string.Empty;

    [RelayCommand]
    private void OpenWebsite() => launcher.Open(Website);

    [RelayCommand]
    private void OpenReleases() => launcher.Open(Website + "/releases");

    [RelayCommand]
    private void ReportProblem() => launcher.Open(Website + "/issues/new");

    [RelayCommand]
    private void ShowShortcuts() => navigation.ShowHelp();
}
