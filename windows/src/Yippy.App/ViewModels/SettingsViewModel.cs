using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Yippy.App.Presentation;
using Yippy.App.Shell;
using Yippy.Domain.History;
using Yippy.Domain.Settings;
using Yippy.UseCases.Abstractions;
using Yippy.UseCases.HotKeys;
using Yippy.UseCases.Settings;

namespace Yippy.App.ViewModels;

public sealed record Option<T>(T Value, string Title);

/// <summary>The settings window. Every change is saved straight away.</summary>
public sealed partial class SettingsViewModel : ObservableObject
{
    private readonly SettingsService settings;
    private readonly IStartupRegistration startup;
    private readonly ToggleHotKeyService hotKey;

    public SettingsViewModel(
        SettingsService settings,
        IStartupRegistration startup,
        ToggleHotKeyService hotKey,
        ITextRecognizer textRecognizer,
        IAppInfoProvider appInfo,
        AppIcons icons,
        IDialogService dialogs)
    {
        this.settings = settings;
        this.startup = startup;
        this.hotKey = hotKey;
        IsTextRecognitionAvailable = textRecognizer.IsAvailable;
        IgnoredApps = new AppListViewModel(
            "Copies made in these apps are not saved to the history, e.g. a password manager:",
            settings, s => s.IgnoredApps, (s, apps) => s with { IgnoredApps = apps }, appInfo, icons, dialogs);
        ExpiringApps = new AppListViewModel(
            "Delete anything copied from these apps after a minute, and clear it from the clipboard, e.g. a terminal:",
            settings, s => s.ExpiringApps, (s, apps) => s with { ExpiringApps = apps }, appInfo, icons, dialogs);
        settings.Changed += (_, _) => OnPropertyChanged(string.Empty);
    }

    public IReadOnlyList<Option<PanelPosition>> Positions { get; } =
        PanelPositions.All.Select(p => new Option<PanelPosition>(p, p.Title())).ToList();

    public IReadOnlyList<int> MaxHistoryOptions => AppSettings.MaxHistoryOptions;

    public IReadOnlyList<Option<int>> MaxAgeOptions { get; } =
        AutoCleanPolicy.MaxAgeDaysOptions.Select(o => new Option<int>(o.Days, o.Title)).ToList();

    public AppListViewModel IgnoredApps { get; }

    public AppListViewModel ExpiringApps { get; }

    public PanelPosition PanelPosition
    {
        get => settings.Current.PanelPosition;
        set => settings.Update(s => s with { PanelPosition = value });
    }

    public int MaxHistory
    {
        get => settings.Current.MaxHistory;
        set => settings.Update(s => s with { MaxHistory = value });
    }

    public bool ShowsRichText
    {
        get => settings.Current.ShowsRichText;
        set => settings.Update(s => s with { ShowsRichText = value });
    }

    public bool PastesRichText
    {
        get => settings.Current.PastesRichText;
        set => settings.Update(s => s with { PastesRichText = value });
    }

    public int MaxItemAgeDays
    {
        get => settings.Current.MaxItemAgeDays;
        set => settings.Update(s => s with { MaxItemAgeDays = value });
    }

    public bool RecognizesTextInImages
    {
        get => settings.Current.RecognizesTextInImages && IsTextRecognitionAvailable;
        set => settings.Update(s => s with { RecognizesTextInImages = value });
    }

    public bool IsTextRecognitionAvailable { get; }

    public string TextRecognitionNote => IsTextRecognitionAvailable
        ? "Each image is read once, in the background, when it's copied. Turning this on reads the images already saved."
        : "Needs a Windows display language with text recognition (Settings › Time & language › Language & region).";

    public bool LaunchAtLogin
    {
        get => startup.IsEnabled;
        set
        {
            startup.SetEnabled(value);
            OnPropertyChanged();
        }
    }

    public string HotKeyText => settings.Current.ToggleHotKey.ToString();

    [ObservableProperty]
    private string? hotKeyMessage;

    /// <summary>While a new shortcut is typed, the current one must not open the panel.</summary>
    public void BeginRecordingHotKey()
    {
        hotKey.Suspend();
        HotKeyMessage = "Type the new shortcut. Esc cancels.";
    }

    public void EndRecordingHotKey()
    {
        hotKey.Resume();
        if (HotKeyMessage == "Type the new shortcut. Esc cancels.")
        {
            HotKeyMessage = null;
        }
    }

    public void SetHotKey(HotKeyGesture gesture)
    {
        if (!gesture.IsValid)
        {
            HotKeyMessage = "Add Ctrl, Alt, Shift or Win, so typing in other apps isn't taken over.";
        }
        else if (hotKey.TryChange(gesture))
        {
            HotKeyMessage = null;
        }
        else
        {
            HotKeyMessage = $"{gesture} is already used by another app. Try another one.";
        }
        OnPropertyChanged(nameof(HotKeyText));
    }

    [RelayCommand]
    private void ResetHotKey() => SetHotKey(HotKeyGesture.DefaultToggle);
}
