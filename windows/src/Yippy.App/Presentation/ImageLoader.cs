using System.Windows.Media.Imaging;

namespace Yippy.App.Presentation;

/// <summary>Decodes item images (PNG or BMP files) into frozen bitmaps that can be made on any thread.</summary>
public static class ImageLoader
{
    /// <param name="maxWidth">Images wider than this are decoded at this width, to save memory in the list.</param>
    public static BitmapSource? Decode(byte[] data, int? maxWidth = null)
    {
        try
        {
            var image = new BitmapImage();
            image.BeginInit();
            image.CacheOption = BitmapCacheOption.OnLoad;
            image.CreateOptions = BitmapCreateOptions.IgnoreColorProfile;
            if (maxWidth is { } width && WidthOf(data) > width)
            {
                image.DecodePixelWidth = width;
            }
            image.StreamSource = new MemoryStream(data);
            image.EndInit();
            image.Freeze();
            return image;
        }
        catch (Exception e) when (e is NotSupportedException or FileFormatException or IOException or InvalidOperationException or ArgumentException)
        {
            return null;
        }
    }

    private static int WidthOf(byte[] data)
    {
        var frame = BitmapFrame.Create(new MemoryStream(data), BitmapCreateOptions.DelayCreation, BitmapCacheOption.None);
        return frame.PixelWidth;
    }
}
