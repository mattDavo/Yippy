namespace Yippy.App.Shell;

/// <summary>The pages of the settings window.</summary>
public enum SettingsPage
{
    General,
    Shortcut,
    History,
    Privacy,
    About,
}

/// <summary>Opens Yippy's windows, for view models that link to them.</summary>
public interface IAppNavigation
{
    /// <param name="page">The page to show, or null to leave the window on the page it shows.</param>
    void ShowSettings(SettingsPage? page = null);

    /// <summary>The keyboard shortcuts.</summary>
    void ShowHelp();
}
