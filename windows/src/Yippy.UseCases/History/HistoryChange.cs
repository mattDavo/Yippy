using Yippy.Domain.History;

namespace Yippy.UseCases.History;

/// <summary>What changed in an <see cref="ItemHistory"/>. Subscribers get the change after the items are updated.</summary>
public abstract record HistoryChange
{
    private HistoryChange()
    {
    }

    public sealed record Inserted(int Index, HistoryItem Item) : HistoryChange;

    /// <summary>One or more items were deleted (one at a time, by the item limit, or by automatic cleaning).</summary>
    public sealed record Deleted(IReadOnlyList<HistoryItem> Items) : HistoryChange;

    public sealed record Cleared : HistoryChange;

    public sealed record Moved(int From, int To) : HistoryChange;

    /// <summary>The item at the index has new metadata, or was replaced by an edited copy.</summary>
    public sealed record Updated(int Index, HistoryItem Item) : HistoryChange;
}
