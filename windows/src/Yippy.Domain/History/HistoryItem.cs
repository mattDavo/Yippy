using Yippy.Domain.Clipboard;
using Yippy.Domain.Search;
using Yippy.Domain.Text;

namespace Yippy.Domain.History;

/// <summary>
/// One copy in a history: its formats, a hash of its content and its metadata. The bytes are read on demand from an
/// <see cref="IItemDataSource"/>, so a long history doesn't sit in memory.
/// </summary>
public sealed class HistoryItem
{
    private readonly IItemDataSource dataSource;
    private readonly Lazy<string?> plainText;
    private readonly Lazy<ItemKind> kind;

    public HistoryItem(Guid id, IReadOnlyList<string> formats, string contentHash, ItemMetadata metadata, IItemDataSource dataSource)
    {
        Id = id;
        Formats = formats;
        ContentHash = contentHash;
        Metadata = metadata;
        this.dataSource = dataSource;
        plainText = new Lazy<string?>(ReadPlainText, LazyThreadSafetyMode.ExecutionAndPublication);
        kind = new Lazy<ItemKind>(() => ItemKinds.Of(Formats, PlainText), LazyThreadSafetyMode.ExecutionAndPublication);
    }

    /// <summary>Unique across all histories; editing a favourite gives it a new id.</summary>
    public Guid Id { get; }

    public IReadOnlyList<string> Formats { get; }

    /// <summary>The <see cref="ClipboardContent.Hash"/> of the item's content.</summary>
    public string ContentHash { get; }

    /// <summary>Changed through the history that holds the item, so the change is saved and announced.</summary>
    public ItemMetadata Metadata { get; private set; }

    public void ChangeMetadata(ItemMetadata metadata) => Metadata = metadata;

    public bool HasFormat(string format) => Formats.Contains(format, StringComparer.Ordinal);

    public byte[]? GetData(string format) => HasFormat(format) ? dataSource.Read(Id, format) : null;

    /// <summary>All the item's data, or null if any of it can't be read.</summary>
    public ClipboardContent? ReadContent()
    {
        var data = new List<KeyValuePair<string, byte[]>>(Formats.Count);
        foreach (var format in Formats)
        {
            if (dataSource.Read(Id, format) is not { } bytes)
            {
                return null;
            }
            data.Add(KeyValuePair.Create(format, bytes));
        }
        return new ClipboardContent(data);
    }

    /// <summary>The item's Unicode text, if it has some. Read once and remembered.</summary>
    public string? PlainText => plainText.Value;

    public ItemKind Kind => kind.Value;

    public bool IsImage => Formats.Any(ClipboardFormats.IsImage);

    /// <summary>The text without styling: the plain text, else the text of the RTF. Null if the item has no text.</summary>
    public string? GetUnstyledText()
    {
        if (PlainText is { } text)
        {
            return text;
        }
        return GetData(ClipboardFormats.Rtf) is { } rtf ? RtfText.ToPlainText(rtf) : null;
    }

    /// <summary>The paths of the copied files, if files were copied.</summary>
    public IReadOnlyList<string> GetFilePaths()
    {
        return GetData(ClipboardFormats.FileDrop) is { } data ? FileDropList.Parse(data) : Array.Empty<string>();
    }

    /// <summary>The best text to show for the item in a list.</summary>
    public string GetDisplayText()
    {
        if (GetUnstyledText() is { } text)
        {
            return text;
        }
        if (GetData(ClipboardFormats.Html) is { } html)
        {
            return HtmlClipboardText.ToPlainText(html);
        }
        var files = GetFilePaths();
        if (files.Count > 0)
        {
            return string.Join(Environment.NewLine, files);
        }
        return IsImage ? "Image" : "Unknown format";
    }

    /// <summary>The image's bytes, as PNG if the item has it, else as a .bmp file.</summary>
    public (byte[] Data, string Format)? GetImage()
    {
        if (GetData(ClipboardFormats.Png) is { } png)
        {
            return (png, ClipboardFormats.Png);
        }
        foreach (var format in new[] { ClipboardFormats.DibV5, ClipboardFormats.Dib })
        {
            if (GetData(format) is { } dib && DibImage.ToBmpFile(dib) is { } bmp)
            {
                return (bmp, format);
            }
        }
        return null;
    }

    private string? ReadPlainText()
    {
        return GetData(ClipboardFormats.UnicodeText) is { } data ? UnicodeText.Decode(data) : null;
    }
}
