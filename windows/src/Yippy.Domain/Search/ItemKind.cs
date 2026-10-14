using Yippy.Domain.Clipboard;
using Yippy.Domain.Text;

namespace Yippy.Domain.Search;

/// <summary>What kind of thing an item is, for the search bar's type filters and for how it is drawn.</summary>
public enum ItemKind
{
    Text,
    Link,
    Image,
    File,
    Color,
}

public static class ItemKinds
{
    /// <summary>The filter words that select each kind, like "/img".</summary>
    public static IReadOnlyList<string> FilterWords(this ItemKind kind) => kind switch
    {
        ItemKind.Text => new[] { "text" },
        ItemKind.Link => new[] { "link", "url" },
        ItemKind.Image => new[] { "img", "image" },
        ItemKind.File => new[] { "file" },
        ItemKind.Color => new[] { "color", "colour" },
        _ => Array.Empty<string>(),
    };

    /// <summary>
    /// The kind of an item with these formats and plain text. Text that is nothing but a web link counts as a link,
    /// and text that is nothing but a hex colour (like #ff8800) as a colour.
    /// </summary>
    public static ItemKind Of(IReadOnlyCollection<string> formats, string? plainText)
    {
        if (formats.Contains(ClipboardFormats.FileDrop))
        {
            return ItemKind.File;
        }
        if (formats.Any(ClipboardFormats.IsImage))
        {
            return ItemKind.Image;
        }
        if (formats.Contains(ClipboardFormats.Url) || formats.Contains(ClipboardFormats.UrlAnsi))
        {
            return ItemKind.Link;
        }
        var text = plainText?.Trim();
        if (string.IsNullOrEmpty(text))
        {
            return ItemKind.Text;
        }
        if (IsLink(text))
        {
            return ItemKind.Link;
        }
        if (HexColor.TryParse(text, out _))
        {
            return ItemKind.Color;
        }
        return ItemKind.Text;
    }

    public static bool IsLink(string text)
    {
        if (text.Any(char.IsWhiteSpace))
        {
            return false;
        }
        return Uri.TryCreate(text, UriKind.Absolute, out var uri)
            && (uri.Scheme == Uri.UriSchemeHttp || uri.Scheme == Uri.UriSchemeHttps || uri.Scheme == Uri.UriSchemeFtp || uri.Scheme == Uri.UriSchemeMailto)
            && (uri.Scheme == Uri.UriSchemeMailto || uri.Host.Length > 0);
    }
}
