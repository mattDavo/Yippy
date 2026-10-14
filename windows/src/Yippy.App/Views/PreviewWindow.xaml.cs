using System.Windows;
using System.Windows.Interop;
using Yippy.Platform.Windows.Display;

namespace Yippy.App.Views;

/// <summary>Shows the selected item larger, beside the panel. It never takes focus, so the panel keeps its keys.</summary>
public partial class PreviewWindow : Window
{
    public PreviewWindow()
    {
        InitializeComponent();
        SourceInitialized += (_, _) => Screens.MakeNonActivating(new WindowInteropHelper(this).Handle);
    }
}
