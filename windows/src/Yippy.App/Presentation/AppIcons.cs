using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Yippy.Domain.Apps;

namespace Yippy.App.Presentation;

/// <summary>The icons of apps, from their executables. Cached; use from the UI thread.</summary>
public sealed class AppIcons
{
    private readonly Dictionary<string, ImageSource?> icons = new(StringComparer.OrdinalIgnoreCase);

    public ImageSource? Get(AppIdentity? app)
    {
        if (app?.Path is not { } path)
        {
            return null;
        }
        if (icons.TryGetValue(path, out var cached))
        {
            return cached;
        }
        var icon = Load(path);
        icons[path] = icon;
        return icon;
    }

    private static ImageSource? Load(string path)
    {
        if (!File.Exists(path))
        {
            return null;
        }
        try
        {
            using var icon = System.Drawing.Icon.ExtractAssociatedIcon(path);
            if (icon is null)
            {
                return null;
            }
            var image = Imaging.CreateBitmapSourceFromHIcon(icon.Handle, Int32Rect.Empty, BitmapSizeOptions.FromEmptyOptions());
            image.Freeze();
            return image;
        }
        catch (Exception e) when (e is ArgumentException or IOException or UnauthorizedAccessException or System.ComponentModel.Win32Exception)
        {
            return null;
        }
    }
}
