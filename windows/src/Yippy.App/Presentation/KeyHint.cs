using System.Windows;
using System.Windows.Controls;

namespace Yippy.App.Presentation;

/// <summary>A keyboard shortcut drawn as keycaps: <c>Keys="Ctrl+D"</c> shows a Ctrl key and a D key. Styled in Themes/Fluent.xaml.</summary>
public sealed class KeyHint : Control
{
    public static readonly DependencyProperty KeysProperty = DependencyProperty.Register(
        nameof(Keys), typeof(string), typeof(KeyHint), new PropertyMetadata(null, (d, e) => ((KeyHint)d).Keycaps = Split((string?)e.NewValue)));

    private static readonly DependencyPropertyKey KeycapsPropertyKey = DependencyProperty.RegisterReadOnly(
        nameof(Keycaps), typeof(IReadOnlyList<string>), typeof(KeyHint), new PropertyMetadata(Array.Empty<string>()));

    public static readonly DependencyProperty KeycapsProperty = KeycapsPropertyKey.DependencyProperty;

    /// <summary>Key names joined with "+", as <see cref="Domain.Settings.HotKeyGesture"/> writes them.</summary>
    public string? Keys
    {
        get => (string?)GetValue(KeysProperty);
        set => SetValue(KeysProperty, value);
    }

    public IReadOnlyList<string> Keycaps
    {
        get => (IReadOnlyList<string>)GetValue(KeycapsProperty);
        private set => SetValue(KeycapsPropertyKey, value);
    }

    private static IReadOnlyList<string> Split(string? keys)
    {
        if (string.IsNullOrEmpty(keys))
        {
            return Array.Empty<string>();
        }
        // "Ctrl++" is Ctrl and the plus key
        var parts = keys.Split('+').ToList();
        if (keys.EndsWith("++", StringComparison.Ordinal))
        {
            parts.RemoveAt(parts.Count - 1);
            parts[^1] = "+";
        }
        return parts.Where(p => p.Length > 0).ToList();
    }
}
