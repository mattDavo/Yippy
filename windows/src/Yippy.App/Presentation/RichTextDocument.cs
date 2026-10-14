using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;

namespace Yippy.App.Presentation;

/// <summary>
/// Lets a read-only <see cref="RichTextBox"/> show RTF bytes from a binding: <c>presentation:RichTextDocument.Rtf="{Binding Rtf}"</c>.
/// </summary>
/// <remarks>The property is typed <see cref="object"/> because the XAML compiler rejects array-typed properties in templates.</remarks>
public static class RichTextDocument
{
    public static readonly DependencyProperty RtfProperty = DependencyProperty.RegisterAttached(
        "Rtf", typeof(object), typeof(RichTextDocument), new PropertyMetadata(null, OnRtfChanged));

    public static object? GetRtf(DependencyObject element) => element.GetValue(RtfProperty);

    /// <param name="value">The RTF file's bytes.</param>
    public static void SetRtf(DependencyObject element, object? value) => element.SetValue(RtfProperty, value);

    private static void OnRtfChanged(DependencyObject element, DependencyPropertyChangedEventArgs e)
    {
        if (element is not RichTextBox box)
        {
            return;
        }
        var document = new FlowDocument { PagePadding = new Thickness(0) };
        if (e.NewValue is byte[] rtf)
        {
            try
            {
                new TextRange(document.ContentStart, document.ContentEnd).Load(new MemoryStream(rtf), DataFormats.Rtf);
            }
            catch (Exception ex) when (ex is ArgumentException or InvalidOperationException or IOException)
            {
                // Leave it empty; the item's plain text is shown in the info bar's tooltip either way
            }
        }
        box.Document = document;
    }
}
