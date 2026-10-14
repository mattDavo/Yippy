using System.Windows;
using Yippy.Domain.Settings;

namespace Yippy.App.Views;

/// <summary>The keyboard shortcuts.</summary>
public partial class HelpWindow : Window
{
    public HelpWindow(HotKeyGesture toggleHotKey)
    {
        InitializeComponent();
        Shortcuts.ItemsSource = new[]
        {
            new Shortcut(toggleHotKey.ToString(), "Open or close Yippy (change it in Settings)"),
            new Shortcut("Up, Down, Page Up/Down", "Select an item"),
            new Shortcut("Enter or double-click", "Paste the selected item"),
            new Shortcut("Shift+Enter", "Paste it as plain text"),
            new Shortcut("Ctrl+0 … Ctrl+9", "Paste the item with that number"),
            new Shortcut("Ctrl+Space", "Preview the selected item"),
            new Shortcut("Ctrl+D", "Add to or remove from favourites"),
            new Shortcut("Ctrl+Tab", "Switch between Clipboard and Favourites"),
            new Shortcut("Ctrl+F", "Search"),
            new Shortcut("Ctrl+Delete", "Delete the selected item (Delete alone when the search is empty)"),
            new Shortcut("Ctrl+Alt+Arrow", "Move the panel to that edge of the screen"),
            new Shortcut("Esc", "Close"),
        };
    }

    public sealed record Shortcut(string Keys, string Action);
}
