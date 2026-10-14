using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using Yippy.App.ViewModels;

namespace Yippy.App.Views;

public partial class AppListEditor : UserControl
{
    public AppListEditor()
    {
        InitializeComponent();
    }

    /// <summary>Lists the apps running now, under the button.</summary>
    private void OnAddClick(object sender, RoutedEventArgs e)
    {
        if (DataContext is not AppListViewModel viewModel)
        {
            return;
        }
        viewModel.RefreshRunningApps();
        RunningAppsMenu.DataContext = viewModel;
        RunningAppsMenu.PlacementTarget = AddButton;
        RunningAppsMenu.Placement = PlacementMode.Bottom;
        RunningAppsMenu.IsOpen = true;
    }
}
