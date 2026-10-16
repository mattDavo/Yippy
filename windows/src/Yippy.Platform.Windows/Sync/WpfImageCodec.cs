using System.IO;
using System.Windows.Media.Imaging;
using Yippy.Domain.Clipboard;
using Yippy.UseCases.Sync;

namespace Yippy.Platform.Windows.Sync;

/// <summary>Converts clipboard bitmaps to and from PNG with WPF's imaging.</summary>
public sealed class WpfImageCodec : IImageCodec
{
    /// <summary>The size of the BITMAPFILEHEADER that a .bmp file has and a CF_DIB doesn't.</summary>
    private const int BmpFileHeaderSize = 14;

    public byte[]? DibToPng(byte[] dib)
    {
        if (DibImage.ToBmpFile(dib) is not { } bmp)
        {
            return null;
        }
        return Convert(bmp, new PngBitmapEncoder());
    }

    public byte[]? PngToDib(byte[] png)
    {
        var bmp = Convert(png, new BmpBitmapEncoder());
        return bmp is { Length: > BmpFileHeaderSize } ? bmp[BmpFileHeaderSize..] : null;
    }

    private static byte[]? Convert(byte[] image, BitmapEncoder encoder)
    {
        try
        {
            var frame = BitmapFrame.Create(new MemoryStream(image), BitmapCreateOptions.IgnoreColorProfile, BitmapCacheOption.OnLoad);
            encoder.Frames.Add(frame);
            using var output = new MemoryStream();
            encoder.Save(output);
            return output.ToArray();
        }
        catch (Exception e) when (e is NotSupportedException or FileFormatException or IOException or InvalidOperationException or ArgumentException)
        {
            return null;
        }
    }
}
