using System.Windows.Controls;
using Yippy.App.ViewModels.Settings;

namespace Yippy.App.Views.Settings;

public partial class ShortcutPage : UserControl
{
    public ShortcutPage()
    {
        InitializeComponent();
        HotKey.RecordingStarted += (_, _) => ViewModel?.BeginRecordingHotKey();
        HotKey.RecordingEnded += (_, _) => ViewModel?.EndRecordingHotKey();
        HotKey.GestureTyped += (_, gesture) => ViewModel?.SetHotKey(gesture);
        // Switching page while a shortcut is being typed mustn't leave the shortcut switched off
        Unloaded += (_, _) => ViewModel?.EndRecordingHotKey();
    }

    private ShortcutPageViewModel? ViewModel => DataContext as ShortcutPageViewModel;
}
