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
            new Shortcut("Open or close Cairn (change it in Settings)", toggleHotKey.ToString()),
            new Shortcut("Select an item", "Up", "Down", "Page Up", "Page Down"),
            new Shortcut("Paste the selected item (or double-click it)", "Enter"),
            new Shortcut("Paste it as plain text", "Shift+Enter"),
            new Shortcut("Paste the item with that number", "Ctrl+0", "…", "Ctrl+9"),
            new Shortcut("Preview the selected item", "Ctrl+Space"),
            new Shortcut("Add to or remove from favourites", "Ctrl+D"),
            new Shortcut("Switch between Clipboard and Favourites", "Ctrl+Tab"),
            new Shortcut("Search", "Ctrl+F"),
            new Shortcut("Delete the selected item (Delete alone when the search is empty)", "Ctrl+Delete"),
            new Shortcut("Move the panel to that edge of the screen", "Ctrl+Alt+Arrow"),
            new Shortcut("Close", "Esc"),
        };
    }

    /// <param name="Keys">Each one a shortcut, as keycaps.</param>
    public sealed record Shortcut(string Action, params string[] Keys);
}
