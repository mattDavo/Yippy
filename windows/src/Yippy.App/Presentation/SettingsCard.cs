using System.Windows;
using System.Windows.Controls;

namespace Yippy.App.Presentation;

/// <summary>
/// One setting: an icon, what it is and what it does, and its control (the content) on the right, or below it for
/// lists. Styled in Themes/Fluent.xaml.
/// </summary>
public sealed class SettingsCard : ContentControl
{
    public static readonly DependencyProperty HeaderProperty =
        DependencyProperty.Register(nameof(Header), typeof(string), typeof(SettingsCard), new PropertyMetadata(null));

    public static readonly DependencyProperty DescriptionProperty =
        DependencyProperty.Register(nameof(Description), typeof(string), typeof(SettingsCard), new PropertyMetadata(null));

    /// <summary>A Segoe Fluent Icons glyph.</summary>
    public static readonly DependencyProperty GlyphProperty =
        DependencyProperty.Register(nameof(Glyph), typeof(string), typeof(SettingsCard), new PropertyMetadata(null));

    public static readonly DependencyProperty IsContentBelowProperty =
        DependencyProperty.Register(nameof(IsContentBelow), typeof(bool), typeof(SettingsCard), new PropertyMetadata(false));

    public string? Header
    {
        get => (string?)GetValue(HeaderProperty);
        set => SetValue(HeaderProperty, value);
    }

    public string? Description
    {
        get => (string?)GetValue(DescriptionProperty);
        set => SetValue(DescriptionProperty, value);
    }

    public string? Glyph
    {
        get => (string?)GetValue(GlyphProperty);
        set => SetValue(GlyphProperty, value);
    }

    /// <summary>Puts the content under the text, full width, e.g. for a list of apps.</summary>
    public bool IsContentBelow
    {
        get => (bool)GetValue(IsContentBelowProperty);
        set => SetValue(IsContentBelowProperty, value);
    }
}
