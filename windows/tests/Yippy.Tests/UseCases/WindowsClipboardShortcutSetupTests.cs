using Yippy.Domain.Settings;
using Yippy.Tests.Fakes;
using Yippy.UseCases.HotKeys;
using Yippy.UseCases.Settings;

namespace Yippy.Tests.UseCases;

/// <summary>The installer's and uninstaller's Win+V commands, which run without Yippy.</summary>
public class WindowsClipboardShortcutSetupTests
{
    private readonly FakeShellClipboardShortcut shell = new(new FakeGlobalHotKeys());

    [Fact]
    public async Task UsingWinVReleasesItAndMakesItYippysShortcut()
    {
        var (settings, repository) = SavedSettings(AppSettings.Default);

        await new WindowsClipboardShortcutSetup(shell, settings).UseWinVAsync(restartShell: true);

        Assert.True(shell.IsReleased);
        Assert.Equal(1, shell.Restarts);
        Assert.Equal(HotKeyGesture.WindowsClipboard, repository.Saved!.ToggleHotKey);
    }

    [Fact]
    public async Task UsingWinVAgainDoesNotRestartExplorer()
    {
        shell.Release();
        var (settings, _) = SavedSettings(AppSettings.Default);

        await new WindowsClipboardShortcutSetup(shell, settings).UseWinVAsync(restartShell: true);

        Assert.Equal(0, shell.Restarts);
    }

    [Fact]
    public async Task WithoutRestartTheChangeWaitsForTheNextSignIn()
    {
        var (settings, _) = SavedSettings(AppSettings.Default);

        await new WindowsClipboardShortcutSetup(shell, settings).UseWinVAsync(restartShell: false);

        Assert.True(shell.IsReleased);
        Assert.Equal(0, shell.Restarts);
    }

    [Fact]
    public async Task BeforeTheFirstLaunchNoSettingsAreSavedButTheFirstLaunchUsesWinV()
    {
        var repository = new InMemorySettingsRepository();
        await new WindowsClipboardShortcutSetup(shell, new SettingsService(repository)).UseWinVAsync(restartShell: true);
        // Saved settings would make Yippy think it had run before (and capture what's on the clipboard)
        Assert.Null(repository.Saved);

        var firstLaunch = new SettingsService(repository);
        new WindowsClipboardShortcutSetup(shell, firstLaunch).ApplyToFirstLaunch();

        Assert.True(firstLaunch.IsFirstLaunch);
        Assert.Equal(HotKeyGesture.WindowsClipboard, firstLaunch.Current.ToggleHotKey);
    }

    [Fact]
    public void LaterLaunchesKeepTheirShortcut()
    {
        shell.Release();
        var custom = new HotKeyGesture('Y', KeyModifiers.Control | KeyModifiers.Alt);
        var (settings, _) = SavedSettings(AppSettings.Default with { ToggleHotKey = custom });

        new WindowsClipboardShortcutSetup(shell, settings).ApplyToFirstLaunch();

        Assert.Equal(custom, settings.Current.ToggleHotKey);
    }

    [Fact]
    public async Task RestoringGivesWinVBackAndResetsYippysShortcut()
    {
        shell.Release();
        var (settings, repository) = SavedSettings(AppSettings.Default with { ToggleHotKey = HotKeyGesture.WindowsClipboard });

        await new WindowsClipboardShortcutSetup(shell, settings).RestoreAsync(restartShell: true);

        Assert.False(shell.IsReleased);
        Assert.Equal(1, shell.Restarts);
        Assert.Equal(HotKeyGesture.DefaultToggle, repository.Saved!.ToggleHotKey);
    }

    [Fact]
    public async Task RestoringWhenWindowsHasWinVChangesNothing()
    {
        var custom = new HotKeyGesture('Y', KeyModifiers.Control | KeyModifiers.Alt);
        var (settings, repository) = SavedSettings(AppSettings.Default with { ToggleHotKey = custom });

        await new WindowsClipboardShortcutSetup(shell, settings).RestoreAsync(restartShell: true);

        Assert.Equal(0, shell.Restarts);
        Assert.Equal(0, repository.Saves);
    }

    private static (SettingsService Settings, InMemorySettingsRepository Repository) SavedSettings(AppSettings saved)
    {
        var repository = new InMemorySettingsRepository(saved);
        return (new SettingsService(repository), repository);
    }
}
