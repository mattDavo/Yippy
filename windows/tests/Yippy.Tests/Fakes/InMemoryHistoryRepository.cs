using Yippy.Domain.Clipboard;
using Yippy.Domain.History;
using Yippy.UseCases.Abstractions;

namespace Yippy.Tests.Fakes;

public sealed class InMemoryHistoryRepository : IHistoryRepository
{
    private readonly List<StoredItem> initial;

    public InMemoryHistoryRepository(params StoredItem[] initial)
    {
        this.initial = initial.ToList();
    }

    public Dictionary<Guid, ClipboardContent> Contents { get; } = new();

    public IReadOnlyList<StoredItem> Index { get; private set; } = Array.Empty<StoredItem>();

    public IReadOnlyList<StoredItem> Load() => initial;

    public byte[]? Read(Guid itemId, string format) => Contents.TryGetValue(itemId, out var c) ? c.Get(format) : null;

    public void Add(Guid id, ClipboardContent content) => Contents[id] = content;

    public void Delete(Guid id) => Contents.Remove(id);

    public void DeleteAll() => Contents.Clear();

    public void SaveIndex(IReadOnlyList<StoredItem> items) => Index = items;

    public Task FlushAsync() => Task.CompletedTask;

    /// <summary>A stored item with this text, for histories that start with items.</summary>
    public StoredItem Store(string text)
    {
        var content = ClipboardContent.FromText(text);
        var item = new StoredItem(Guid.NewGuid(), content.FormatNames.ToList(), content.Hash, ItemMetadata.None);
        Contents[item.Id] = content;
        initial.Add(item);
        return item;
    }
}
