using Yippy.Domain.Apps;

namespace Yippy.Domain.History;

/// <summary>
/// What Yippy knows about an item besides its clipboard data. Every field is optional.
/// </summary>
public sealed record ItemMetadata
{
    /// <summary>The app that owned the clipboard (or was in front) when the item was copied.</summary>
    public AppIdentity? Source { get; init; }

    /// <summary>When the item was last copied.</summary>
    public DateTimeOffset? CopiedAt { get; init; }

    /// <summary>A name the user gave the item (favourites only).</summary>
    public string? Title { get; init; }

    /// <summary>Text read out of the item's image, or "" if none was found. Null if the image hasn't been read.</summary>
    public string? RecognizedText { get; init; }

    public static ItemMetadata None { get; } = new();
}
