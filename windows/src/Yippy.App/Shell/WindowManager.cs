using System.Windows;
using Microsoft.Win32;
using Yippy.App.ViewModels;
using Yippy.App.Views;
using Yippy.UseCases.Settings;

namespace Yippy.App.Shell;

/// <summary>Opens Yippy's windows and dialogs, one of each kind at a time.</summary>
public sealed class WindowManager : IDialogService
{
    private readonly Func<SettingsViewModel> settingsViewModel;
    private readonly SettingsService settings;
    private readonly Dictionary<Type, Window> open = new();

    /// <param name="settingsViewModel">Makes the settings window's view model; it is only needed once the window opens.</param>
    public WindowManager(Func<SettingsViewModel> settingsViewModel, SettingsService settings)
    {
        this.settingsViewModel = settingsViewModel;
        this.settings = settings;
    }

    public void ShowSettings() => ShowSingle(() => new SettingsWindow(settingsViewModel()));

    public void ShowAbout() => ShowSingle(() => new AboutWindow());

    public void ShowHelp() => ShowSingle(() => new HelpWindow(settings.Current.ToggleHotKey));

    public string? Prompt(string title, string message, string initialText, bool multiline = false)
    {
        var window = new PromptWindow(title, message, initialText, multiline);
        return ShowDialog(window) ? window.Text : null;
    }

    public bool Confirm(string title, string message)
    {
        return MessageBox.Show(message, title, MessageBoxButton.OKCancel, MessageBoxImage.Question, MessageBoxResult.Cancel)
            == MessageBoxResult.OK;
    }

    public string? PickExecutable()
    {
        var dialog = new OpenFileDialog
        {
            Title = "Choose an App",
            Filter = "Apps (*.exe)|*.exe",
            InitialDirectory = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
        };
        return dialog.ShowDialog(ActiveWindow()) == true ? dialog.FileName : null;
    }

    private void ShowSingle<T>(Func<T> create) where T : Window
    {
        if (!open.TryGetValue(typeof(T), out var window))
        {
            window = create();
            open[typeof(T)] = window;
            window.Closed += (_, _) => open.Remove(typeof(T));
            window.Show();
        }
        if (window.WindowState == WindowState.Minimized)
        {
            window.WindowState = WindowState.Normal;
        }
        window.Activate();
    }

    private static bool ShowDialog(Window window)
    {
        window.Owner = ActiveWindow();
        window.Activate();
        return window.ShowDialog() == true;
    }

    private static Window? ActiveWindow() =>
        Application.Current.Windows.OfType<Window>().FirstOrDefault(w => w.IsActive && w.IsVisible);
}
