using System.Windows;

namespace Yippy.App.Views;

/// <summary>Asks for a line of text, or several.</summary>
public partial class PromptWindow : Window
{
    public PromptWindow(string title, string message, string initialText, bool multiline)
    {
        InitializeComponent();
        Title = title;
        MessageText.Text = message;
        Input.Text = initialText;
        if (multiline)
        {
            // Enter adds a line; Ctrl+Enter isn't needed because Save is a click away
            Input.AcceptsReturn = true;
            Input.AcceptsTab = true;
            Input.TextWrapping = TextWrapping.Wrap;
            Input.VerticalScrollBarVisibility = System.Windows.Controls.ScrollBarVisibility.Auto;
            Input.Height = 220;
            Input.FontFamily = (System.Windows.Media.FontFamily)FindResource("Yippy.MonoFont");
        }
        Loaded += (_, _) =>
        {
            Input.Focus();
            Input.SelectAll();
        };
    }

    public string Text => Input.Text;

    private void OnSave(object sender, RoutedEventArgs e) => DialogResult = true;
}
