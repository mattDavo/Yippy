using System.Collections.ObjectModel;
using System.Windows.Media;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Yippy.App.Presentation;
using Yippy.App.Shell;
using Yippy.Domain.Apps;
using Yippy.Domain.Settings;
using Yippy.UseCases.Abstractions;
using Yippy.UseCases.Settings;

namespace Yippy.App.ViewModels.Settings;

/// <summary>An app in a settings list.</summary>
public sealed record AppEntry(AppIdentity App, string Name, ImageSource? Icon)
{
    public string Id => App.Id;
}

/// <summary>
/// A list of apps in the settings (ignored apps, or apps whose copies expire), saved as one of the settings.
/// </summary>
public sealed partial class AppListViewModel : ObservableObject
{
    private readonly SettingsService settings;
    private readonly Func<AppSettings, IReadOnlyList<AppIdentity>> read;
    private readonly Func<AppSettings, IReadOnlyList<AppIdentity>, AppSettings> write;
    private readonly IAppInfoProvider appInfo;
    private readonly AppIcons icons;
    private readonly IDialogService dialogs;

    public AppListViewModel(
        SettingsService settings,
        Func<AppSettings, IReadOnlyList<AppIdentity>> read,
        Func<AppSettings, IReadOnlyList<AppIdentity>, AppSettings> write,
        IAppInfoProvider appInfo,
        AppIcons icons,
        IDialogService dialogs)
    {
        this.settings = settings;
        this.read = read;
        this.write = write;
        this.appInfo = appInfo;
        this.icons = icons;
        this.dialogs = dialogs;
        Load();
        settings.Changed += (_, e) =>
        {
            if (!read(e.Old).SequenceEqual(read(e.Current)))
            {
                Load();
            }
        };
    }

    public ObservableCollection<AppEntry> Apps { get; } = new();

    [ObservableProperty]
    [NotifyCanExecuteChangedFor(nameof(RemoveCommand))]
    private AppEntry? selectedApp;

    /// <summary>Apps with a window open that aren't in the list yet, for the Add menu.</summary>
    [ObservableProperty]
    private IReadOnlyList<AppEntry> runningApps = Array.Empty<AppEntry>();

    public void RefreshRunningApps()
    {
        var current = read(settings.Current);
        RunningApps = appInfo.GetRunningApps()
            .Where(app => !current.Contains(app))
            .Select(Entry)
            .ToList();
    }

    [RelayCommand]
    private void Add(AppEntry? entry)
    {
        if (entry is not null)
        {
            AddApp(entry.App);
        }
    }

    [RelayCommand]
    private void Browse()
    {
        if (dialogs.PickExecutable() is { } path)
        {
            AddApp(AppIdentity.FromPath(path));
        }
    }

    [RelayCommand(CanExecute = nameof(CanRemove))]
    private void Remove()
    {
        if (SelectedApp is { } entry)
        {
            settings.Update(s => write(s, read(s).Where(app => !app.Equals(entry.App)).ToList()));
        }
    }

    private bool CanRemove() => SelectedApp is not null;

    private void AddApp(AppIdentity app)
    {
        settings.Update(s => read(s).Contains(app) ? s : write(s, read(s).Append(app).ToList()));
    }

    private void Load()
    {
        Apps.Clear();
        foreach (var app in read(settings.Current).OrderBy(appInfo.GetDisplayName, StringComparer.CurrentCultureIgnoreCase))
        {
            Apps.Add(Entry(app));
        }
    }

    private AppEntry Entry(AppIdentity app) => new(app, appInfo.GetDisplayName(app), icons.Get(app));
}
