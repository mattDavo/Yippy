using Yippy.App.Shell;
using Yippy.Domain.Settings;
using Yippy.UseCases.Abstractions;
using Yippy.UseCases.Settings;

namespace Yippy.App.ViewModels.Settings;

/// <summary>Starting with Windows, where the panel opens, and styled text.</summary>
public sealed class GeneralPageViewModel : SettingsPageViewModel
{
    private readonly IStartupRegistration startup;

    public GeneralPageViewModel(SettingsService settings, IStartupRegistration startup)
        : base(SettingsPage.General, "General", "", settings)
    {
        this.startup = startup;
    }

    public bool LaunchAtLogin
    {
        get => startup.IsEnabled;
        set
        {
            startup.SetEnabled(value);
            OnPropertyChanged();
        }
    }

    public IReadOnlyList<Option<PanelPosition>> Positions { get; } =
        PanelPositions.All.Select(p => new Option<PanelPosition>(p, p.Title())).ToList();

    public PanelPosition PanelPosition
    {
        get => Settings.Current.PanelPosition;
        set => Settings.Update(s => s with { PanelPosition = value });
    }

    public bool ShowsRichText
    {
        get => Settings.Current.ShowsRichText;
        set => Settings.Update(s => s with { ShowsRichText = value });
    }

    public bool PastesRichText
    {
        get => Settings.Current.PastesRichText;
        set => Settings.Update(s => s with { PastesRichText = value });
    }
}
