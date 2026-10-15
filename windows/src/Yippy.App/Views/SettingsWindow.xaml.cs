using System.Windows;
using Yippy.App.ViewModels.Settings;

namespace Yippy.App.Views;

public partial class SettingsWindow : Window
{
    public SettingsWindow(SettingsViewModel viewModel)
    {
        InitializeComponent();
        DataContext = viewModel;
        // Don't leave the shortcut switched off if the window closes while one is being typed
        Closed += (_, _) => viewModel.Shortcut.EndRecordingHotKey();
    }
}
