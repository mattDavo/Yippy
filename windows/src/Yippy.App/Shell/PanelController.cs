using System.ComponentModel;
using System.Windows.Interop;
using Yippy.App.ViewModels;
using Yippy.App.Views;
using Yippy.Domain.Settings;
using Yippy.Platform.Windows.Display;
using Yippy.Platform.Windows.Input;
using Yippy.UseCases.Settings;

namespace Yippy.App.Shell;

/// <summary>
/// Opens and closes the history panel and its preview, on the screen the mouse is on, at the position in the settings.
/// </summary>
public sealed class PanelController
{
    private const long ReopenDelayMilliseconds = 400;

    private readonly PanelViewModel viewModel;
    private readonly SettingsService settings;
    private readonly ForegroundWindowTracker foregroundWindows;
    private readonly PanelWindow panel;
    private readonly PreviewWindow preview;
    private (ScreenRect WorkArea, double Scale) screen;
    private bool isHiding;
    private long hiddenOnDeactivationAt;

    public PanelController(PanelViewModel viewModel, SettingsService settings, ForegroundWindowTracker foregroundWindows)
    {
        this.viewModel = viewModel;
        this.settings = settings;
        this.foregroundWindows = foregroundWindows;
        panel = new PanelWindow { DataContext = viewModel };
        preview = new PreviewWindow { DataContext = viewModel };

        viewModel.CloseRequested += (_, _) => Hide(restoreFocus: true);
        viewModel.PropertyChanged += OnViewModelChanged;
        // Clicking another app closes the panel, as on macOS
        panel.Deactivated += (_, _) =>
        {
            if (IsShown && !isHiding)
            {
                hiddenOnDeactivationAt = Environment.TickCount64;
                Hide(restoreFocus: false);
            }
        };
        settings.Changed += (_, e) =>
        {
            if (e.Old.PanelPosition != e.Current.PanelPosition && IsShown)
            {
                Place();
            }
        };
    }

    public bool IsShown => panel.IsVisible;

    public void Toggle()
    {
        // Clicking the tray icon while the panel is open first deactivates the panel, which hides it; don't open it again
        if (!IsShown && Environment.TickCount64 - hiddenOnDeactivationAt < ReopenDelayMilliseconds)
        {
            return;
        }
        if (IsShown)
        {
            Hide(restoreFocus: true);
        }
        else
        {
            Show();
        }
    }

    public void Show()
    {
        if (IsShown)
        {
            panel.Activate();
            return;
        }
        screen = Screens.AtCursor();
        new WindowInteropHelper(panel).EnsureHandle();
        Place();
        viewModel.OnShown();
        panel.Show();
        // Showing on a screen with another scale factor can resize the window, so place it again
        Place();
        panel.Activate();
        panel.FocusSearch();
    }

    /// <param name="restoreFocus">Give the app that was in front before back its focus (not when another app was clicked).</param>
    public void Hide(bool restoreFocus)
    {
        // Hiding the panel deactivates it, which would hide it again
        if (!IsShown || isHiding)
        {
            return;
        }
        isHiding = true;
        viewModel.IsPreviewOpen = false;
        preview.Hide();
        panel.Hide();
        isHiding = false;
        if (restoreFocus)
        {
            foregroundWindows.ActivateLastExternalWindow();
        }
    }

    private void OnViewModelChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName is nameof(PanelViewModel.IsPreviewOpen) or nameof(PanelViewModel.SelectedItem))
        {
            UpdatePreview();
        }
    }

    private void UpdatePreview()
    {
        if (!IsShown || !viewModel.IsPreviewOpen || viewModel.SelectedItem is null)
        {
            preview.Hide();
            return;
        }
        if (!preview.IsVisible)
        {
            new WindowInteropHelper(preview).EnsureHandle();
            PlacePreview();
            preview.Show();
        }
        PlacePreview();
    }

    private void Place()
    {
        var position = settings.Current.PanelPosition;
        Screens.SetBounds(new WindowInteropHelper(panel).Handle, PanelLayout.GetFrame(position, screen.WorkArea, screen.Scale));
        if (preview.IsVisible)
        {
            PlacePreview();
        }
    }

    private void PlacePreview()
    {
        var frame = PanelLayout.GetFrame(settings.Current.PanelPosition, screen.WorkArea, screen.Scale);
        var bounds = PanelLayout.GetPreviewFrame(settings.Current.PanelPosition, frame, screen.WorkArea, screen.Scale);
        Screens.SetBounds(new WindowInteropHelper(preview).Handle, bounds);
    }
}
