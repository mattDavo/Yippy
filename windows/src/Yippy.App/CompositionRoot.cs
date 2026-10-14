using Microsoft.Extensions.DependencyInjection;
using Yippy.App.Presentation;
using Yippy.App.Shell;
using Yippy.App.ViewModels;
using Yippy.Infrastructure.Hosting;
using Yippy.Infrastructure.Logging;
using Yippy.Infrastructure.Settings;
using Yippy.Infrastructure.Storage;
using Yippy.Platform.Windows.Apps;
using Yippy.Platform.Windows.Clipboard;
using Yippy.Platform.Windows.Input;
using Yippy.Platform.Windows.Native;
using Yippy.Platform.Windows.Ocr;
using Yippy.UseCases.Abstractions;
using Yippy.UseCases.Caching;
using Yippy.UseCases.Capture;
using Yippy.UseCases.Cleaning;
using Yippy.UseCases.History;
using Yippy.UseCases.HotKeys;
using Yippy.UseCases.Paste;
using Yippy.UseCases.Recognition;
using Yippy.UseCases.Search;
using Yippy.UseCases.Settings;

namespace Yippy.App;

/// <summary>
/// Wires every layer together: the Windows adapters and file storage behind the use cases' ports, and the use cases into
/// the view models. The only place that knows the concrete types. Build it on the UI thread.
/// </summary>
public static class CompositionRoot
{
    /// <summary>The key of the clipboard history's <see cref="ItemHistory"/> and repository.</summary>
    public const string Clipboard = "clipboard";

    /// <summary>The key of the favourites' <see cref="ItemHistory"/> and repository.</summary>
    public const string Favourites = "favourites";

    public static ServiceProvider Build(AppPaths paths, Action quit)
    {
        var services = new ServiceCollection();
        AddInfrastructure(services, paths);
        AddPlatform(services);
        AddUseCases(services);
        AddPresentation(services, quit);
        return services.BuildServiceProvider(new ServiceProviderOptions { ValidateOnBuild = true, ValidateScopes = true });
    }

    private static void AddInfrastructure(IServiceCollection services, AppPaths paths)
    {
        services.AddSingleton(paths);
        services.AddSingleton<IAppLogger>(_ => new FileAppLogger(paths.Root));
        services.AddSingleton<IClock, SystemClock>();
        services.AddSingleton<ISettingsRepository>(s => new JsonSettingsRepository(paths.Settings, s.GetRequiredService<IAppLogger>()));
        services.AddKeyedSingleton<FileHistoryRepository>(Clipboard,
            (s, _) => new FileHistoryRepository(paths.History, s.GetRequiredService<IAppLogger>()));
        services.AddKeyedSingleton<FileHistoryRepository>(Favourites,
            (s, _) => new FileHistoryRepository(paths.Favourites, s.GetRequiredService<IAppLogger>()));
    }

    private static void AddPlatform(IServiceCollection services)
    {
        services.AddSingleton<MessageWindow>();
        services.AddSingleton<ForegroundWindowTracker>();
        services.AddSingleton<IClipboard>(s => new Win32Clipboard(s.GetRequiredService<MessageWindow>(), s.GetRequiredService<IAppLogger>()));
        services.AddSingleton<IClipboardMonitor>(s => new ClipboardMonitor(s.GetRequiredService<MessageWindow>()));
        services.AddSingleton<IGlobalHotKeys>(s => new GlobalHotKeys(s.GetRequiredService<MessageWindow>()));
        services.AddSingleton<IPasteSimulator>(s =>
            new SendInputPasteSimulator(s.GetRequiredService<ForegroundWindowTracker>(), s.GetRequiredService<IAppLogger>()));
        services.AddSingleton<ITextRecognizer, WindowsOcrTextRecognizer>();
        services.AddSingleton<IAppInfoProvider, WindowsAppInfoProvider>();
        services.AddSingleton<IStartupRegistration>(s => new RegistryStartupRegistration(App.InstanceName, s.GetRequiredService<IAppLogger>()));
    }

    private static void AddUseCases(IServiceCollection services)
    {
        services.AddSingleton<SettingsService>();
        // The clipboard history keeps as many items as the settings say and moves pasted items to the top;
        // the favourites keep everything, in the user's order
        services.AddKeyedSingleton<ItemHistory>(Clipboard, (s, key) =>
        {
            var repository = s.GetRequiredKeyedService<FileHistoryRepository>(key);
            var maxItems = s.GetRequiredService<SettingsService>().Current.MaxHistory;
            return new ItemHistory(repository, new CachingItemDataSource(repository), maxItems, movesPastedItemToTop: true);
        });
        services.AddKeyedSingleton<ItemHistory>(Favourites, (s, key) =>
        {
            var repository = s.GetRequiredKeyedService<FileHistoryRepository>(key);
            return new ItemHistory(repository, new CachingItemDataSource(repository), int.MaxValue, movesPastedItemToTop: false);
        });
        services.AddSingleton(s => new ClipboardCaptureService(
            s.GetRequiredService<IClipboard>(),
            s.GetRequiredService<IClipboardMonitor>(),
            s.GetRequiredKeyedService<ItemHistory>(Clipboard),
            s.GetRequiredService<SettingsService>(),
            s.GetRequiredService<IClock>()));
        services.AddSingleton(s => new HistoryEditingService(
            s.GetRequiredKeyedService<ItemHistory>(Clipboard),
            s.GetRequiredKeyedService<ItemHistory>(Favourites),
            s.GetRequiredService<IClipboard>(),
            s.GetRequiredService<ClipboardCaptureService>()));
        services.AddSingleton(s => new AutoCleanService(
            s.GetRequiredKeyedService<ItemHistory>(Clipboard),
            s.GetRequiredService<IClipboard>(),
            s.GetRequiredService<ClipboardCaptureService>(),
            s.GetRequiredService<SettingsService>(),
            s.GetRequiredService<IClock>()));
        services.AddSingleton(s => new TextRecognitionService(
            s.GetRequiredService<ITextRecognizer>(),
            s.GetRequiredService<SettingsService>(),
            s.GetRequiredService<IAppLogger>(),
            s.GetRequiredKeyedService<ItemHistory>(Clipboard),
            s.GetRequiredKeyedService<ItemHistory>(Favourites)));
        services.AddSingleton(s => new HistorySettingsSync(
            s.GetRequiredService<SettingsService>(),
            s.GetRequiredKeyedService<ItemHistory>(Clipboard)));
        services.AddSingleton<PasteService>();
        services.AddSingleton<SearchService>();
        services.AddSingleton<ToggleHotKeyService>();
    }

    private static void AddPresentation(IServiceCollection services, Action quit)
    {
        services.AddSingleton<AppIcons>();
        services.AddSingleton<ItemContext>();
        services.AddSingleton(s => new WindowManager(s.GetRequiredService<SettingsViewModel>, s.GetRequiredService<SettingsService>()));
        services.AddSingleton<IDialogService>(s => s.GetRequiredService<WindowManager>());
        services.AddSingleton<PanelViewModel>();
        services.AddSingleton<SettingsViewModel>();
        services.AddSingleton<PanelController>();
        services.AddSingleton(s => new TrayIcon(
            s.GetRequiredService<PanelController>(),
            s.GetRequiredService<WindowManager>(),
            s.GetRequiredService<SettingsService>(),
            s.GetRequiredService<IStartupRegistration>(),
            s.GetRequiredService<HistoryEditingService>(),
            quit));
    }
}
