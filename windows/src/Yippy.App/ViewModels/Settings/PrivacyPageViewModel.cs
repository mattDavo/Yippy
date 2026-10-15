using CommunityToolkit.Mvvm.Input;
using Yippy.App.Shell;
using Yippy.UseCases.Abstractions;
using Yippy.UseCases.Settings;

namespace Yippy.App.ViewModels.Settings;

/// <summary>What Yippy doesn't keep, what it reads, and where it keeps everything.</summary>
public sealed partial class PrivacyPageViewModel : SettingsPageViewModel
{
    private readonly ILauncher launcher;

    /// <param name="dataFolder">Where the history, favourites and settings are saved.</param>
    public PrivacyPageViewModel(
        SettingsService settings, ITextRecognizer textRecognizer, ILauncher launcher, AppListViewModel ignoredApps, string dataFolder)
        : base(SettingsPage.Privacy, "Privacy", "", settings)
    {
        this.launcher = launcher;
        IgnoredApps = ignoredApps;
        DataFolder = dataFolder;
        IsTextRecognitionAvailable = textRecognizer.IsAvailable;
    }

    /// <summary>Apps whose copies are never saved.</summary>
    public AppListViewModel IgnoredApps { get; }

    public bool RecognizesTextInImages
    {
        get => Settings.Current.RecognizesTextInImages && IsTextRecognitionAvailable;
        set => Settings.Update(s => s with { RecognizesTextInImages = value });
    }

    public bool IsTextRecognitionAvailable { get; }

    public string TextRecognitionNote => IsTextRecognitionAvailable
        ? "Search finds images by the words in them. Images are read on this PC by Windows; nothing is sent anywhere."
        : "Needs a Windows display language with text recognition: Settings › Time & language › Language & region.";

    public string DataFolder { get; }

    [RelayCommand]
    private void OpenDataFolder()
    {
        Directory.CreateDirectory(DataFolder);
        launcher.Open(DataFolder);
    }
}
