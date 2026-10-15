using System.Runtime.InteropServices;
using System.Runtime.InteropServices.WindowsRuntime;
using Windows.Graphics.Imaging;
using Windows.Media.Ocr;
using Windows.Storage.Streams;
using Yippy.UseCases.Abstractions;

namespace Yippy.Platform.Windows.Ocr;

/// <summary>Reads the text in images with Windows' built-in OCR, in the languages of the user's profile.</summary>
public sealed class WindowsOcrTextRecognizer : ITextRecognizer
{
    private readonly Lazy<OcrEngine?> engine = new(CreateEngine);

    public bool IsAvailable => engine.Value is not null;

    public async Task<string?> RecognizeAsync(byte[] image, CancellationToken cancellationToken)
    {
        if (engine.Value is not { } ocr)
        {
            return null;
        }
        using var stream = new InMemoryRandomAccessStream();
        await stream.WriteAsync(image.AsBuffer()).AsTask(cancellationToken);
        stream.Seek(0);
        var decoder = await BitmapDecoder.CreateAsync(stream).AsTask(cancellationToken);

        // OCR only takes images up to a size, so shrink larger ones
        var max = OcrEngine.MaxImageDimension;
        var scale = Math.Min(1.0, Math.Min((double)max / decoder.PixelWidth, (double)max / decoder.PixelHeight));
        var transform = new BitmapTransform
        {
            ScaledWidth = (uint)Math.Max(1, decoder.PixelWidth * scale),
            ScaledHeight = (uint)Math.Max(1, decoder.PixelHeight * scale),
            InterpolationMode = BitmapInterpolationMode.Fant,
        };
        using var bitmap = await decoder.GetSoftwareBitmapAsync(
            BitmapPixelFormat.Bgra8,
            BitmapAlphaMode.Premultiplied,
            transform,
            ExifOrientationMode.RespectExifOrientation,
            ColorManagementMode.DoNotColorManage).AsTask(cancellationToken);

        var result = await ocr.RecognizeAsync(bitmap).AsTask(cancellationToken);
        return string.Join('\n', result.Lines.Select(line => line.Text));
    }

    /// <summary>Null when no OCR language is installed, or Windows' OCR isn't there at all (some trimmed editions).</summary>
    private static OcrEngine? CreateEngine()
    {
        try
        {
            return OcrEngine.TryCreateFromUserProfileLanguages();
        }
        catch (COMException)
        {
            return null;
        }
    }
}
