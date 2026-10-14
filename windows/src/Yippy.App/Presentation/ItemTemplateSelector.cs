using System.Windows;
using System.Windows.Controls;
using Yippy.App.ViewModels;

namespace Yippy.App.Presentation;

/// <summary>Picks how an item's content is drawn from its <see cref="ItemPresentation"/>.</summary>
public sealed class ItemTemplateSelector : DataTemplateSelector
{
    public DataTemplate? Text { get; set; }

    public DataTemplate? RichText { get; set; }

    public DataTemplate? Link { get; set; }

    public DataTemplate? Image { get; set; }

    public DataTemplate? Files { get; set; }

    public DataTemplate? Color { get; set; }

    public override DataTemplate? SelectTemplate(object? item, DependencyObject container)
    {
        return (item as ItemViewModel)?.Presentation switch
        {
            ItemPresentation.RichText => RichText,
            ItemPresentation.Link => Link ?? Text,
            ItemPresentation.Image => Image,
            ItemPresentation.Files => Files,
            ItemPresentation.Color => Color,
            _ => Text,
        };
    }
}
