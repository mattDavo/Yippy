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
    public const string InstanceName = Brand.Name + " Dev";

    /// <summary>The same build's name before the rename, which <see cref="LegacyMigration"/> moves over.</summary>
    public const string LegacyInstanceName = Brand.LegacyName + " Dev";
#else
    public const string InstanceName = Brand.Name;

    public const string LegacyInstanceName = Brand.LegacyName;
#endif

    private static readonly TimeSpan FlushTimeout = TimeSpan.FromSeconds(5);

    private SingleInstance? instance;
    private ThemeManager? theme;
    private ServiceProvider? services;
    private DispatcherTimer? cleanTimer;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // A second launch opens the running copy's panel instead of starting another one
        instance = new SingleInstance(InstanceName);
        if (!instance.IsFirst)
        {
            instance.RequestShow();
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

        var settings = services.GetRequiredService<SettingsService>();
        // The installer may have handed Win+V to Yippy before its first launch
        services.GetRequiredService<WindowsClipboardShortcutSetup>().ApplyToFirstLaunch();
        StartBackgroundServices(services, settings.IsFirstLaunch);
        var panel = services.GetRequiredService<PanelController>();
        var tray = services.GetRequiredService<TrayIcon>();
        instance.OnShowRequested(() => Dispatcher.BeginInvoke(panel.Show));
        instance.OnQuitRequested(() => Dispatcher.BeginInvoke(() => Shutdown()));

        var hotKey = services.GetRequiredService<ToggleHotKeyService>();
        if (!hotKey.Start(panel.Toggle))
        {
            tray.Notify("Shortcut unavailable",
                $"Another app uses {hotKey.Current}. Click the Cairn icon, or choose another shortcut in Settings.", isWarning: true);
        }
        else if (settings.IsFirstLaunch)
        {
            tray.Notify("Cairn is running",
                $"Press {hotKey.Current} to see everything you copy. Cairn lives here, in the notification area.");
        }
    }

    protected override void OnExit(ExitEventArgs e)
    {
        cleanTimer?.Stop();
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
        instance?.Dispose();
        base.OnExit(e);
    }

    private void StartBackgroundServices(IServiceProvider provider, bool isFirstLaunch)
    {
        // These work through events, so they only need creating
        var capture = provider.GetRequiredService<ClipboardCaptureService>();
        provider.GetRequiredService<HistorySettingsSync>();
        provider.GetRequiredService<TextRecognitionService>();

        if (isFirstLaunch)
        {
            // Whatever was copied before Yippy was installed may be private; start with an empty history
            capture.IgnoreCurrentContent();
        }
        else
        {
            // Pick up anything copied while Yippy wasn't running
            capture.Capture();
        }

        var clean = provider.GetRequiredService<AutoCleanService>();
        clean.Clean();
        cleanTimer = new DispatcherTimer(AutoCleanService.Interval, DispatcherPriority.Background, (_, _) => clean.Clean(), Dispatcher);
        cleanTimer.Start();
    }
}
