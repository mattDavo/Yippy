using System.Windows;
using System.Windows.Threading;
using Microsoft.Extensions.DependencyInjection;
using Yippy.App.Presentation;
using Yippy.App.Shell;
using Yippy.Infrastructure.Hosting;
using Yippy.UseCases.Abstractions;
using Yippy.UseCases.Capture;
using Yippy.UseCases.Cleaning;
using Yippy.UseCases.HotKeys;
using Yippy.UseCases.Recognition;
using Yippy.UseCases.Settings;

namespace Yippy.App;

/// <summary>
/// Starts Yippy in the notification area: one copy per user, listening to the clipboard, with the global shortcut registered.
/// </summary>
public partial class App : System.Windows.Application
{
#if DEBUG
    /// <summary>Development builds keep their own history, settings and sign-in entry, like the macOS Beta build.</summary>
    public const string InstanceName = "Yippy Dev";
#else
    public const string InstanceName = "Yippy";
#endif

    private static readonly TimeSpan FlushTimeout = TimeSpan.FromSeconds(5);

    private Mutex? instanceMutex;
    private EventWaitHandle? showEvent;
    private RegisteredWaitHandle? showWait;
    private ThemeManager? theme;
    private ServiceProvider? services;
    private DispatcherTimer? cleanTimer;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // A second launch opens the running copy's panel instead of starting another one
        instanceMutex = new Mutex(initiallyOwned: true, $@"Local\{InstanceName}.Instance", out var isFirstInstance);
        showEvent = new EventWaitHandle(false, EventResetMode.AutoReset, $@"Local\{InstanceName}.Show");
        if (!isFirstInstance)
        {
            showEvent.Set();
            Shutdown();
            return;
        }

        theme = new ThemeManager(Resources);
        services = CompositionRoot.Build(AppPaths.ForCurrentUser(InstanceName), Shutdown);
        var logger = services.GetRequiredService<IAppLogger>();
        DispatcherUnhandledException += (_, args) =>
        {
            logger.Error("Unhandled exception", args.Exception);
            args.Handled = true;
        };

        StartBackgroundServices(services);
        var panel = services.GetRequiredService<PanelController>();
        var tray = services.GetRequiredService<TrayIcon>();
        showWait = ThreadPool.RegisterWaitForSingleObject(showEvent, (_, _) => Dispatcher.BeginInvoke(panel.Show), null, Timeout.Infinite, false);

        var settings = services.GetRequiredService<SettingsService>();
        var hotKey = services.GetRequiredService<ToggleHotKeyService>();
        if (!hotKey.Start(panel.Toggle))
        {
            tray.Notify("Shortcut unavailable",
                $"Another app uses {hotKey.Current}. Click the Yippy icon, or choose another shortcut in Settings.", isWarning: true);
        }
        else if (settings.IsFirstLaunch)
        {
            tray.Notify("Yippy is running",
                $"Press {hotKey.Current} to see everything you copy. Yippy lives here, in the notification area.");
        }
    }

    protected override void OnExit(ExitEventArgs e)
    {
        cleanTimer?.Stop();
        showWait?.Unregister(null);
        if (services is not null)
        {
            // Let the last writes reach the disk before the process ends
            foreach (var key in new[] { CompositionRoot.Clipboard, CompositionRoot.Favourites })
            {
                services.GetRequiredKeyedService<Infrastructure.Storage.FileHistoryRepository>(key).FlushAsync().Wait(FlushTimeout);
            }
            services.Dispose();
        }
        theme?.Dispose();
        showEvent?.Dispose();
        instanceMutex?.Dispose();
        base.OnExit(e);
    }

    private void StartBackgroundServices(IServiceProvider provider)
    {
        // These work through events, so they only need creating
        var capture = provider.GetRequiredService<ClipboardCaptureService>();
        provider.GetRequiredService<HistorySettingsSync>();
        provider.GetRequiredService<TextRecognitionService>();

        // Pick up anything copied while Yippy wasn't running
        capture.Capture();

        var clean = provider.GetRequiredService<AutoCleanService>();
        clean.Clean();
        cleanTimer = new DispatcherTimer(AutoCleanService.Interval, DispatcherPriority.Background, (_, _) => clean.Clean(), Dispatcher);
        cleanTimer.Start();
    }
}
