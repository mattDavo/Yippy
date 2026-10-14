using System.Globalization;
using System.Windows;
using System.Windows.Data;

namespace Yippy.App.Presentation;

/// <summary>True (or a non-empty value) is visible; false, null and "" are collapsed. <c>ConverterParameter=Invert</c> flips it.</summary>
public sealed class VisibleWhenConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        var visible = value switch
        {
            bool b => b,
            string s => s.Length > 0,
            int i => i > 0,
            null => false,
            _ => true,
        };
        if (parameter as string == "Invert")
        {
            visible = !visible;
        }
        return visible ? Visibility.Visible : Visibility.Collapsed;
    }

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        throw new NotSupportedException();
    }
}
