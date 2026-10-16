using System.Text;
using Yippy.Domain.Clipboard;
using Yippy.Domain.Sync;
using Yippy.Domain.Text;

namespace Yippy.UseCases.Sync;

/// <summary>
/// Converts between the Windows clipboard formats an item is stored in and the formats it is synced in (Adapter).
/// </summary>
public sealed class SyncFormatMapper
{
    private readonly IImageCodec images;

    public SyncFormatMapper(IImageCodec images)
    {
        this.images = images;
    }

    /// <returns>The synced formats of the content; empty if it has none of them (e.g. copied files).</returns>
    public SyncContent ToSync(ClipboardContent content)
    {
        var formats = new List<KeyValuePair<string, byte[]>>();
        if (content.Get(ClipboardFormats.UnicodeText) is { } text)
        {
            formats.Add(KeyValuePair.Create(SyncFormats.Text, Encoding.UTF8.GetBytes(UnicodeText.Decode(text))));
        }
        if (content.Get(ClipboardFormats.Rtf) is { } rtf)
        {
            formats.Add(KeyValuePair.Create(SyncFormats.Rtf, TrimNull(rtf)));
        }
        if (content.Get(ClipboardFormats.Html) is { } html)
        {
            formats.Add(KeyValuePair.Create(SyncFormats.Html, Encoding.UTF8.GetBytes(HtmlClipboardText.GetFragment(html))));
        }
        var png = content.Get(ClipboardFormats.Png);
        if (png is null && (content.Get(ClipboardFormats.DibV5) ?? content.Get(ClipboardFormats.Dib)) is { } dib)
        {
            png = images.DibToPng(dib);
        }
        if (png is not null)
        {
            formats.Add(KeyValuePair.Create(SyncFormats.Png, png));
        }
        return new SyncContent(formats);
    }

    public ClipboardContent ToClipboard(SyncContent content)
    {
        var formats = new List<KeyValuePair<string, byte[]>>();
        if (content.Text is { } text)
        {
            formats.Add(KeyValuePair.Create(ClipboardFormats.UnicodeText, UnicodeText.Encode(text)));
        }
        if (content.Get(SyncFormats.Rtf) is { } rtf)
        {
            formats.Add(KeyValuePair.Create(ClipboardFormats.Rtf, rtf));
        }
        if (content.Get(SyncFormats.Html) is { } html)
        {
            formats.Add(KeyValuePair.Create(ClipboardFormats.Html, HtmlClipboardText.Wrap(Encoding.UTF8.GetString(html))));
        }
        if (content.Get(SyncFormats.Png) is { } png)
        {
            formats.Add(KeyValuePair.Create(ClipboardFormats.Png, png));
            // Most apps only paste the bitmap format
            if (images.PngToDib(png) is { } dib)
            {
                formats.Add(KeyValuePair.Create(ClipboardFormats.Dib, dib));
            }
        }
        return new ClipboardContent(formats);
    }

    private static byte[] TrimNull(byte[] data)
    {
        var length = data.Length;
        while (length > 0 && data[length - 1] == 0)
        {
            length--;
        }
        return length == data.Length ? data : data[..length];
    }
}
