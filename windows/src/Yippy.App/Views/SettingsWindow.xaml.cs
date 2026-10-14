using System.Windows;
using Yippy.App.ViewModels;

namespace Yippy.App.Views;

public partial class SettingsWindow : Window
{
    public SettingsWindow(SettingsViewModel viewModel)
    {
        InitializeComponent();
        DataContext = viewModel;
        HotKey.RecordingStarted += (_, _) => viewModel.BeginRecordingHotKey();
        HotKey.RecordingEnded += (_, _) => viewModel.EndRecordingHotKey();
        HotKey.GestureTyped += (_, gesture) => viewModel.SetHotKey(gesture);
        // Don't leave the shortcut switched off if the window closes while one is being typed
        Closed += (_, _) => viewModel.EndRecordingHotKey();
    }
}
