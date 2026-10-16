using Yippy.Domain.History;

namespace Yippy.UseCases.History;

/// <summary>
/// What the user did to the histories, as opposed to what Yippy did by itself (trimming to the limit, automatic cleaning,
/// or applying another device's changes). Sync sends these to the user's other devices.
/// </summary>
public interface IHistoryActivity
{
    /// <summary>Something was copied: a new item, or an item already in the history copied again.</summary>
    void Copied(HistoryItem item);

    /// <summary>The user deleted items from a history.</summary>
    void Deleted(ItemHistory history, IReadOnlyList<HistoryItem> items);

    /// <summary>The user cleared a history.</summary>
    void Cleared(ItemHistory history);

    /// <summary>A favourite was added, renamed, or replaced by an edited copy (<paramref name="replaced"/>).</summary>
    void FavouriteChanged(HistoryItem favourite, HistoryItem? replaced = null);
}

/// <summary>Ignores the activity, for when nothing listens (Null Object pattern).</summary>
public sealed class NoHistoryActivity : IHistoryActivity
{
    public static NoHistoryActivity Instance { get; } = new();

    public void Copied(HistoryItem item)
    {
    }

    public void Deleted(ItemHistory history, IReadOnlyList<HistoryItem> items)
    {
    }

    public void Cleared(ItemHistory history)
    {
    }

    public void FavouriteChanged(HistoryItem favourite, HistoryItem? replaced = null)
    {
    }
}
