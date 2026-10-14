using Yippy.Domain.Clipboard;
using Yippy.Domain.History;
using Yippy.UseCases.Abstractions;

namespace Yippy.UseCases.History;

/// <summary>
/// An ordered list of copies: the clipboard history, or the favourites.
/// </summary>
/// <remarks>
/// Changes the list in memory, tells subscribers (<see cref="Changed"/>, Observer pattern) and hands the disk work to the
/// <see cref="IHistoryRepository"/>. Use from the UI thread only.
/// </remarks>
public sealed class ItemHistory
{
    private readonly List<HistoryItem> items;
    private readonly Dictionary<string, int> hashCounts = new(StringComparer.Ordinal);
    private readonly IHistoryRepository repository;
    private readonly IItemDataSource dataSource;

    /// <param name="dataSource">Where items read their data; usually the repository behind a cache.</param>
    /// <param name="movesPastedItemToTop">True for the clipboard history. Favourites keep their order when pasted.</param>
    public ItemHistory(IHistoryRepository repository, IItemDataSource dataSource, int maxItems, bool movesPastedItemToTop)
    {
        this.repository = repository;
        this.dataSource = dataSource;
        MovesPastedItemToTop = movesPastedItemToTop;
        MaxItems = maxItems;
        items = repository.Load()
            .Select(s => new HistoryItem(s.Id, s.Formats, s.ContentHash, s.Metadata, dataSource))
            .ToList();
        foreach (var item in items)
        {
            CountHash(item, 1);
        }
        if (items.Count > maxItems)
        {
            DeleteRange(maxItems, items.Count - maxItems);
            SaveIndex();
        }
    }

    public event EventHandler<HistoryChange>? Changed;

    public IReadOnlyList<HistoryItem> Items => items;

    public int MaxItems { get; private set; }

    public bool MovesPastedItemToTop { get; }

    public int IndexOf(Guid id) => items.FindIndex(i => i.Id == id);

    /// <summary>Index of an item with exactly this content, if there is one.</summary>
    public int IndexOfContent(string contentHash) => items.FindIndex(i => i.ContentHash == contentHash);

    /// <summary>Whether an item with exactly this content is in the history. Cheap enough to ask for every row drawn.</summary>
    public bool ContainsContent(string contentHash) => hashCounts.ContainsKey(contentHash);

    /// <summary>Adds a new item holding <paramref name="content"/>, then deletes the oldest items beyond the limit.</summary>
    public HistoryItem Add(ClipboardContent content, ItemMetadata metadata, int index = 0)
    {
        var item = new HistoryItem(Guid.NewGuid(), content.FormatNames.ToList(), content.Hash, metadata, dataSource);
        repository.Add(item.Id, content);
        items.Insert(index, item);
        CountHash(item, 1);
        Notify(new HistoryChange.Inserted(index, item));
        if (items.Count > MaxItems)
        {
            DeleteRange(MaxItems, items.Count - MaxItems);
        }
        SaveIndex();
        return item;
    }

    public void Delete(Guid id)
    {
        var index = IndexOf(id);
        if (index >= 0)
        {
            DeleteRange(index, 1);
            SaveIndex();
        }
    }

    /// <summary>Deletes every item <paramref name="shouldDelete"/> picks, telling subscribers once.</summary>
    /// <returns>The deleted items.</returns>
    public IReadOnlyList<HistoryItem> DeleteWhere(Func<HistoryItem, bool> shouldDelete)
    {
        var deleted = items.Where(shouldDelete).ToList();
        if (deleted.Count == 0)
        {
            return deleted;
        }
        var ids = deleted.Select(i => i.Id).ToHashSet();
        items.RemoveAll(i => ids.Contains(i.Id));
        foreach (var item in deleted)
        {
            CountHash(item, -1);
            repository.Delete(item.Id);
        }
        Notify(new HistoryChange.Deleted(deleted));
        SaveIndex();
        return deleted;
    }

    public void Clear()
    {
        items.Clear();
        hashCounts.Clear();
        repository.DeleteAll();
        Notify(new HistoryChange.Cleared());
        SaveIndex();
    }

    public void Move(int from, int to)
    {
        if (from == to || from < 0 || to < 0 || from >= items.Count || to >= items.Count)
        {
            return;
        }
        var item = items[from];
        items.RemoveAt(from);
        items.Insert(to, item);
        Notify(new HistoryChange.Moved(from, to));
        SaveIndex();
    }

    public void SetMaxItems(int maxItems)
    {
        MaxItems = maxItems;
        if (items.Count > maxItems)
        {
            DeleteRange(maxItems, items.Count - maxItems);
            SaveIndex();
        }
    }

    /// <summary>Changes the metadata of the item with this id, if it's still in the history.</summary>
    public void UpdateMetadata(Guid id, Func<ItemMetadata, ItemMetadata> change)
    {
        var index = IndexOf(id);
        if (index < 0)
        {
            return;
        }
        var item = items[index];
        var metadata = change(item.Metadata);
        if (metadata == item.Metadata)
        {
            return;
        }
        item.ChangeMetadata(metadata);
        Notify(new HistoryChange.Updated(index, item));
        SaveIndex();
    }

    /// <summary>
    /// Replaces the item with a new one holding <paramref name="content"/>, keeping its place and metadata. Used to edit favourites.
    /// </summary>
    /// <remarks>The new item gets a new id, so nothing cached for the old one is used for it.</remarks>
    public HistoryItem? Replace(Guid id, ClipboardContent content)
    {
        var index = IndexOf(id);
        if (index < 0)
        {
            return null;
        }
        var old = items[index];
        var item = new HistoryItem(Guid.NewGuid(), content.FormatNames.ToList(), content.Hash, old.Metadata, dataSource);
        // Store the new item before removing the old one, so a crash in between loses nothing
        repository.Add(item.Id, content);
        repository.Delete(old.Id);
        CountHash(old, -1);
        CountHash(item, 1);
        items[index] = item;
        Notify(new HistoryChange.Updated(index, item));
        SaveIndex();
        return item;
    }

    private void DeleteRange(int index, int count)
    {
        var deleted = items.GetRange(index, count);
        items.RemoveRange(index, count);
        foreach (var item in deleted)
        {
            CountHash(item, -1);
            repository.Delete(item.Id);
        }
        Notify(new HistoryChange.Deleted(deleted));
    }

    private void CountHash(HistoryItem item, int delta)
    {
        var count = hashCounts.GetValueOrDefault(item.ContentHash) + delta;
        if (count > 0)
        {
            hashCounts[item.ContentHash] = count;
        }
        else
        {
            hashCounts.Remove(item.ContentHash);
        }
    }

    private void SaveIndex()
    {
        repository.SaveIndex(items.Select(i => new StoredItem(i.Id, i.Formats, i.ContentHash, i.Metadata)).ToList());
    }

    private void Notify(HistoryChange change) => Changed?.Invoke(this, change);
}
