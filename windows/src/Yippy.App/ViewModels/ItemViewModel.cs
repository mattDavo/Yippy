using System.Windows.Media;
using CommunityToolkit.Mvvm.ComponentModel;
using Yippy.App.Presentation;
using Yippy.Domain.Clipboard;
using Yippy.Domain.History;
using Yippy.Domain.Search;
using Yippy.Domain.Text;
using Yippy.Domain.Transforms;
using Yippy.UseCases.History;

namespace Yippy.App.ViewModels;

/// <summary>How an item is drawn, which picks its template.</summary>
public enum ItemPresentation
{
    Text,
    RichText,
    Link,
    Image,
    Files,
    Color,
}

/// <summary>One item in the panel's list.</summary>
public sealed partial class ItemViewModel : ObservableObject
{
    /// <summary>Text beyond this is cut off in the list; the preview shows it all.</summary>
    private const int MaxListTextLength = 3000;

    /// <summary>Images in the list are decoded at most this wide.</summary>
    private const int ThumbnailWidth = 720;

    private readonly ItemContext context;
    private string? text;
    private ImageSource? thumbnail;
    private ImageSource? image;
    private bool isLoadingThumbnail;
    private bool isLoadingImage;
    private IReadOnlyList<TransformOption>? transforms;

    public ItemViewModel(HistoryItem item, ItemHistory history, PanelViewModel panel, ItemContext context)
    {
        Item = item;
        History = history;
        Panel = panel;
        this.context = context;
        Presentation = PresentationOf(item, context.Settings.Current.ShowsRichText);
    }

    public HistoryItem Item { get; }

    public ItemHistory History { get; }

    /// <summary>For the bindings of the item's buttons and right-click menu.</summary>
    public PanelViewModel Panel { get; }

    public ItemPresentation Presentation { get; }

    /// <summary>The row in the list, for the Ctrl+0…9 hints.</summary>
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(ShortcutKey))]
    [NotifyPropertyChangedFor(nameof(ShortcutToolTip))]
    private int index;

    /// <summary>The number key that pastes this item with Ctrl, shown as a keycap.</summary>
    public string? ShortcutKey => Index < 10 ? Index.ToString(System.Globalization.CultureInfo.InvariantCulture) : null;

    public string? ShortcutToolTip => Index < 10 ? $"Ctrl+{Index} pastes this" : null;

    public string Text => text ??= Truncate(Item.GetDisplayText());

    public string FullText => Item.GetDisplayText();

    public byte[]? Rtf => Presentation == ItemPresentation.RichText ? Item.GetData(ClipboardFormats.Rtf) : null;

    /// <summary>A smaller copy of the image for the list, decoded in the background on first use.</summary>
    public ImageSource? Thumbnail
    {
        get
        {
            if (thumbnail is null && !isLoadingThumbnail && Presentation == ItemPresentation.Image)
            {
                isLoadingThumbnail = true;
                _ = LoadImageAsync(ThumbnailWidth, decoded => thumbnail = decoded, nameof(Thumbnail));
            }
            return thumbnail;
        }
    }

    /// <summary>The image at full size, for the preview.</summary>
    public ImageSource? Image
    {
        get
        {
            if (image is null && !isLoadingImage && Presentation == ItemPresentation.Image)
            {
                isLoadingImage = true;
                _ = LoadImageAsync(null, decoded => image = decoded, nameof(Image));
            }
            return image;
        }
    }

    public IReadOnlyList<string> FilePaths => Item.GetFilePaths();

    public string FileSummary
    {
        get
        {
            var paths = FilePaths;
            return paths.Count switch
            {
                0 => "Files",
                1 => Path.GetFileName(paths[0].TrimEnd('\\')),
                _ => $"{Path.GetFileName(paths[0].TrimEnd('\\'))} and {paths.Count - 1} more",
            };
        }
    }

    public Brush? ColorBrush
    {
        get
        {
            if (Presentation != ItemPresentation.Color || !HexColor.TryParse(Item.PlainText ?? string.Empty, out var c))
            {
                return null;
            }
            var brush = new SolidColorBrush(System.Windows.Media.Color.FromArgb(c.A, c.R, c.G, c.B));
            brush.Freeze();
            return brush;
        }
    }

    public string? Title => Item.Metadata.Title;

    public ImageSource? SourceIcon => context.Icons.Get(Item.Metadata.Source);

    public string? SourceName => Item.Metadata.Source is { } source ? context.AppInfo.GetDisplayName(source) : null;

    /// <summary>"Visual Studio Code, 5 min ago", under every item.</summary>
    public string InfoText
    {
        get
        {
            var parts = new List<string>();
            if (SourceName is { } name)
            {
                parts.Add(name);
            }
            if (Item.Metadata.CopiedAt is { } copiedAt)
            {
                parts.Add(TimeAgo.Format(copiedAt, context.Clock.Now));
            }
            return string.Join(", ", parts);
        }
    }

    public string? CopiedAtToolTip => Item.Metadata.CopiedAt?.ToLocalTime().ToString("f");

    public bool IsInFavourites => History == context.Editing.Favourites;

    public bool IsFavourite => IsInFavourites || context.Editing.IsFavourite(Item);

    public string FavouriteGlyph => IsFavourite ? "" : "";

    public string FavouriteToolTip => IsFavourite ? "Remove from Favourites (Ctrl+D)" : "Add to Favourites (Ctrl+D)";

    public string FavouriteMenuTitle => IsFavourite ? "Remove from Favourites" : "Add to Favourites";

    public bool CanRename => IsInFavourites;

    public bool CanEdit => IsInFavourites && Item.GetUnstyledText() is not null;

    public bool HasSource => Item.Metadata.Source is not null;

    public string ShowFromAppTitle => $"Show Items from {SourceName}";

    public bool HasText => Item.GetUnstyledText() is not null;

    public IReadOnlyList<TransformOption> Transforms => transforms ??= TextTransforms.All.Select(t => new TransformOption(this, t)).ToList();

    /// <summary>Updates everything shown, e.g. after the metadata changed or to move "5 min ago" on.</summary>
    public void Refresh()
    {
        OnPropertyChanged(nameof(Title));
        OnPropertyChanged(nameof(InfoText));
        OnPropertyChanged(nameof(CopiedAtToolTip));
        RefreshFavourite();
    }

    public void RefreshFavourite()
    {
        OnPropertyChanged(nameof(IsFavourite));
        OnPropertyChanged(nameof(FavouriteGlyph));
        OnPropertyChanged(nameof(FavouriteToolTip));
        OnPropertyChanged(nameof(FavouriteMenuTitle));
    }

    private static ItemPresentation PresentationOf(HistoryItem item, bool showsRichText)
    {
        return item.Kind switch
        {
            ItemKind.Image => ItemPresentation.Image,
            ItemKind.File => ItemPresentation.Files,
            ItemKind.Color => ItemPresentation.Color,
            ItemKind.Link => ItemPresentation.Link,
            _ when showsRichText && item.HasFormat(ClipboardFormats.Rtf) => ItemPresentation.RichText,
            _ => ItemPresentation.Text,
        };
    }

    private static string Truncate(string text)
    {
        return text.Length > MaxListTextLength ? text[..MaxListTextLength] + "…" : text;
    }

    private async Task LoadImageAsync(int? maxWidth, Action<ImageSource?> store, string propertyName)
    {
        var decoded = await Task.Run(() => Item.GetImage() is { } source ? ImageLoader.Decode(source.Data, maxWidth) : null);
        store(decoded);
        OnPropertyChanged(propertyName);
    }
}

/// <summary>A "Paste Transformed" menu entry for one item.</summary>
public sealed class TransformOption
{
    private bool? isApplicable;

    public TransformOption(ItemViewModel item, ITextTransform transform)
    {
        Item = item;
        Transform = transform;
    }

    public ItemViewModel Item { get; }

    public ITextTransform Transform { get; }

    public string Title => Transform.Title;

    /// <summary>Whether the transform changes the item's text, worked out when the menu opens.</summary>
    public bool IsApplicable => isApplicable ??= Item.Item.GetUnstyledText() is { } text && Transform.Apply(text) is { } result && result != text;
}
