using CommunityToolkit.Mvvm.Input;
using Yippy.App.Shell;
using Yippy.Domain.History;
using Yippy.Domain.Settings;
using Yippy.UseCases.History;
using Yippy.UseCases.Settings;

namespace Yippy.App.ViewModels.Settings;

/// <summary>How much history is kept, and for how long.</summary>
public sealed partial class HistoryPageViewModel : SettingsPageViewModel
{
    private readonly HistoryEditingService editing;
    private readonly IDialogService dialogs;

    public HistoryPageViewModel(SettingsService settings, HistoryEditingService editing, IDialogService dialogs, AppListViewModel expiringApps)
        : base(SettingsPage.History, "History", "", settings)
    {
        this.editing = editing;
        this.dialogs = dialogs;
        ExpiringApps = expiringApps;
        editing.ClipboardHistory.Changed += (_, _) =>
        {
            OnPropertyChanged(nameof(ItemCountText));
            ClearHistoryCommand.NotifyCanExecuteChanged();
        };
    }

    public IReadOnlyList<int> MaxHistoryOptions => AppSettings.MaxHistoryOptions;

    public int MaxHistory
    {
        get => Settings.Current.MaxHistory;
        set => Settings.Update(s => s with { MaxHistory = value });
    }

    public IReadOnlyList<Option<int>> MaxAgeOptions { get; } =
        AutoCleanPolicy.MaxAgeDaysOptions.Select(o => new Option<int>(o.Days, o.Title)).ToList();

    public int MaxItemAgeDays
    {
        get => Settings.Current.MaxItemAgeDays;
        set => Settings.Update(s => s with { MaxItemAgeDays = value });
    }

    /// <summary>Apps whose copies are deleted after a minute.</summary>
    public AppListViewModel ExpiringApps { get; }

    public string ItemCountText => editing.ClipboardHistory.Items.Count switch
    {
        0 => "The clipboard history is empty.",
        1 => "1 item in the clipboard history. Favourites are kept.",
        var count => $"{count} items in the clipboard history. Favourites are kept.",
    };

    [RelayCommand(CanExecute = nameof(CanClearHistory))]
    private void ClearHistory()
    {
        if (dialogs.Confirm("Clear History", "Delete every item in the clipboard history? Favourites are kept. This can't be undone."))
        {
            editing.Clear(editing.ClipboardHistory);
        }
    }

    private bool CanClearHistory() => editing.ClipboardHistory.Items.Count > 0;
}
