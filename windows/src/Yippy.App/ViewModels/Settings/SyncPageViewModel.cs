using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Yippy.App.Shell;
using Yippy.Domain.Clipboard;
using Yippy.Domain.Sync;
using Yippy.UseCases.Abstractions;
using Yippy.UseCases.Capture;
using Yippy.UseCases.Settings;
using Yippy.UseCases.Sync;

namespace Yippy.App.ViewModels.Settings;

/// <summary>
/// Syncing copies and favourites with the user's other devices: the server, the sync key, and whether it's working.
/// The fields are only saved when sync is turned on, so a half-typed address never breaks a working setup.
/// </summary>
public sealed partial class SyncPageViewModel : SettingsPageViewModel
{
    private readonly SyncService sync;
    private readonly IDialogService dialogs;
    private readonly IClipboard clipboard;
    private readonly ClipboardCaptureService capture;

    public SyncPageViewModel(SettingsService settings, SyncService sync, IDialogService dialogs, IClipboard clipboard, ClipboardCaptureService capture)
        : base(SettingsPage.Sync, "Sync", "", settings)
    {
        this.sync = sync;
        this.dialogs = dialogs;
        this.clipboard = clipboard;
        this.capture = capture;
        serverAddress = settings.Current.SyncServer ?? string.Empty;
        accessKey = settings.Current.SyncAccessKey ?? string.Empty;
        syncKey = sync.Key?.ToString() ?? string.Empty;
        sync.StatusChanged += (_, _) => OnPropertyChanged(nameof(StatusText));
    }

    [ObservableProperty]
    private string serverAddress;

    [ObservableProperty]
    private string accessKey;

    [ObservableProperty]
    private string syncKey;

    /// <summary>Why the fields can't be used, or null.</summary>
    [ObservableProperty]
    private string? message;

    public bool IsOn => sync.IsEnabled;

    public string TurnOnText => IsOn ? "Save changes" : "Turn on sync";

    public string StatusText => sync.Status.Kind switch
    {
        SyncStatusKind.Off => "Off. Copies and favourites stay on this PC.",
        SyncStatusKind.Connecting => "Connecting…",
        SyncStatusKind.UpToDate => $"Up to date. Last synced {sync.Status.LastSynced?.ToLocalTime():t}.",
        SyncStatusKind.Offline => $"Offline: {sync.Status.Message} Changes are sent when the server is back.",
        SyncStatusKind.Refused => $"Not syncing: {sync.Status.Message}",
        _ => string.Empty,
    };

    [RelayCommand]
    private void NewKey()
    {
        if (SyncKey.Length > 0 && !dialogs.Confirm("New Sync Key",
                "Make a new sync key? Devices using the old one won't see what this PC syncs until you enter the new key on them."))
        {
            return;
        }
        SyncKey = Domain.Sync.SyncKey.Generate().ToString();
    }

    /// <summary>Copies the key to paste on another device, without it going into the history.</summary>
    [RelayCommand]
    private void CopyKey()
    {
        if (SyncKey.Length > 0)
        {
            capture.RecordOwnChange(clipboard.Write(ClipboardContent.FromText(SyncKey)));
        }
    }

    [RelayCommand]
    private void TurnOn()
    {
        if (!SyncServerAddress.TryParse(ServerAddress, out var address, out var error))
        {
            Message = error;
            return;
        }
        if (SyncKey.Trim().Length == 0)
        {
            SyncKey = Domain.Sync.SyncKey.Generate().ToString();
        }
        if (!Domain.Sync.SyncKey.TryParse(SyncKey, out var key))
        {
            Message = "That sync key isn't complete. Copy it again from the other device.";
            return;
        }
        Message = null;
        ServerAddress = address.ToString();
        SyncKey = key.ToString();
        sync.TurnOn(address, AccessKey, key);
        OnPropertyChanged(string.Empty);
    }

    [RelayCommand]
    private void TurnOff()
    {
        sync.TurnOff();
        OnPropertyChanged(string.Empty);
    }

    [RelayCommand]
    private async Task EraseServerData()
    {
        if (!dialogs.Confirm("Erase Synced Data",
                "Delete everything this sync key stored on the server and turn sync off? Items stay on this PC. Other devices stop syncing until you set up a new key."))
        {
            return;
        }
        try
        {
            await sync.EraseServerDataAsync();
            SyncKey = string.Empty;
            Message = null;
        }
        catch (SyncServerException e)
        {
            Message = e.Message;
        }
        OnPropertyChanged(string.Empty);
    }
}
