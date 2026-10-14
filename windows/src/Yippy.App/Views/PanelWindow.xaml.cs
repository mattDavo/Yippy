using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Threading;
using Yippy.App.ViewModels;
using Yippy.Domain.Settings;

namespace Yippy.App.Views;

/// <summary>
/// The history panel. Keyboard focus stays in the search box, so typing searches straight away; this code-behind turns
/// the panel's shortcuts and drag and drop into view model calls.
/// </summary>
public partial class PanelWindow : Window
{
    private Point? dragStart;

    public PanelWindow()
    {
        InitializeComponent();
        // Clicking an item focuses it; give focus back to the search box so typing still searches
        ItemList.GotKeyboardFocus += (_, _) => Dispatcher.BeginInvoke(() => Keyboard.Focus(SearchBox), DispatcherPriority.Input);
    }

    private PanelViewModel ViewModel => (PanelViewModel)DataContext;

    /// <summary>Puts the cursor in the search box with its text selected, so typing replaces the last search.</summary>
    public void FocusSearch()
    {
        SearchBox.Focus();
        Keyboard.Focus(SearchBox);
        SearchBox.SelectAll();
    }

    private void OnPreviewKeyDown(object sender, KeyEventArgs e)
    {
        var key = e.Key == Key.System ? e.SystemKey : e.Key;
        var modifiers = Keyboard.Modifiers;
        var ctrl = modifiers.HasFlag(ModifierKeys.Control);
        var shift = modifiers.HasFlag(ModifierKeys.Shift);
        var alt = modifiers.HasFlag(ModifierKeys.Alt);
        e.Handled = true;

        switch (key)
        {
            case Key.Down when !ctrl:
                ViewModel.MoveSelection(1);
                break;
            case Key.Up when !ctrl:
                ViewModel.MoveSelection(-1);
                break;
            case Key.PageDown:
                ViewModel.MoveSelection(5);
                break;
            case Key.PageUp:
                ViewModel.MoveSelection(-5);
                break;
            case Key.Enter when shift:
                ViewModel.PastePlainTextCommand.Execute(null);
                break;
            case Key.Enter:
                ViewModel.PasteCommand.Execute(null);
                break;
            case Key.Escape:
                ViewModel.CloseCommand.Execute(null);
                break;
            case Key.Left when ctrl && alt:
                ViewModel.SetPosition(PanelPosition.Left);
                break;
            case Key.Right when ctrl && alt:
                ViewModel.SetPosition(PanelPosition.Right);
                break;
            case Key.Up when ctrl && alt:
                ViewModel.SetPosition(PanelPosition.Top);
                break;
            case Key.Down when ctrl && alt:
                ViewModel.SetPosition(PanelPosition.Bottom);
                break;
            case Key.Delete when ctrl || SearchBox.Text.Length == 0:
                ViewModel.DeleteCommand.Execute(null);
                break;
            case Key.Space when ctrl:
                ViewModel.TogglePreviewCommand.Execute(null);
                break;
            case Key.F when ctrl:
                FocusSearch();
                break;
            case Key.D when ctrl:
                ViewModel.ToggleFavouriteCommand.Execute(null);
                break;
            case Key.Tab when ctrl:
                ViewModel.SwitchGroupCommand.Execute(null);
                break;
            case >= Key.D0 and <= Key.D9 when ctrl:
                ViewModel.PasteAtCommand.Execute(key - Key.D0);
                break;
            case >= Key.NumPad0 and <= Key.NumPad9 when ctrl:
                ViewModel.PasteAtCommand.Execute(key - Key.NumPad0);
                break;
            case Key.Apps:
            case Key.F10 when shift:
                OpenSelectedItemMenu();
                break;
            default:
                e.Handled = false;
                break;
        }
    }

    private void OpenSelectedItemMenu()
    {
        if (ItemList.ItemContainerGenerator.ContainerFromItem(ViewModel.SelectedItem) is ListBoxItem container
            && FindMenuOwner(container) is { ContextMenu: { } menu } owner)
        {
            menu.PlacementTarget = owner;
            menu.IsOpen = true;
        }
    }

    private static FrameworkElement? FindMenuOwner(DependencyObject parent)
    {
        for (var i = 0; i < System.Windows.Media.VisualTreeHelper.GetChildrenCount(parent); i++)
        {
            var child = System.Windows.Media.VisualTreeHelper.GetChild(parent, i);
            if (child is FrameworkElement { ContextMenu: not null } element)
            {
                return element;
            }
            if (FindMenuOwner(child) is { } found)
            {
                return found;
            }
        }
        return null;
    }

    private void OnSelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (ItemList.SelectedItem is { } item)
        {
            ItemList.ScrollIntoView(item);
        }
    }

    private void OnItemDoubleClick(object sender, MouseButtonEventArgs e)
    {
        if (sender is ListBoxItem { DataContext: ItemViewModel item })
        {
            ViewModel.PasteCommand.Execute(item);
            e.Handled = true;
        }
    }

    // Drag an item onto another to move it there

    private void OnItemMouseDown(object sender, MouseButtonEventArgs e)
    {
        dragStart = e.GetPosition(this);
    }

    private void OnItemMouseMove(object sender, MouseEventArgs e)
    {
        if (e.LeftButton != MouseButtonState.Pressed || dragStart is not { } start || sender is not ListBoxItem { DataContext: ItemViewModel item } container)
        {
            return;
        }
        var moved = e.GetPosition(this) - start;
        if (Math.Abs(moved.X) < SystemParameters.MinimumHorizontalDragDistance && Math.Abs(moved.Y) < SystemParameters.MinimumVerticalDragDistance)
        {
            return;
        }
        dragStart = null;
        DragDrop.DoDragDrop(container, new DataObject(typeof(ItemViewModel), item), DragDropEffects.Move);
    }

    private void OnItemDragOver(object sender, DragEventArgs e)
    {
        e.Effects = e.Data.GetDataPresent(typeof(ItemViewModel)) ? DragDropEffects.Move : DragDropEffects.None;
        e.Handled = true;
    }

    private void OnItemDrop(object sender, DragEventArgs e)
    {
        if (e.Data.GetData(typeof(ItemViewModel)) is ItemViewModel dragged
            && sender is ListBoxItem { DataContext: ItemViewModel target }
            && dragged != target)
        {
            ViewModel.Move(dragged, target);
            e.Handled = true;
        }
    }
}
