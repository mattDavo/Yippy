using Yippy.Domain.Clipboard;
using Yippy.Domain.History;
using Yippy.Tests.Fakes;
using Yippy.UseCases.History;

namespace Yippy.Tests.UseCases;

public class ItemHistoryTests
{
    private readonly InMemoryHistoryRepository repository = new();

    private ItemHistory Create(int maxItems = 10) => new(repository, repository, maxItems, movesPastedItemToTop: true);

    private static IReadOnlyList<string?> Texts(ItemHistory history) => history.Items.Select(i => i.PlainText).ToList();

    [Fact]
    public void LoadsStoredItemsInOrder()
    {
        repository.Store("a");
        repository.Store("b");

        Assert.Equal(new[] { "a", "b" }, Texts(Create()));
    }

    [Fact]
    public void TrimsStoredItemsBeyondTheLimit()
    {
        repository.Store("a");
        repository.Store("b");
        repository.Store("c");

        var history = Create(maxItems: 2);

        Assert.Equal(new[] { "a", "b" }, Texts(history));
        Assert.Equal(2, repository.Contents.Count);
        Assert.Equal(2, repository.Index.Count);
    }

    [Fact]
    public void AddsAtTheTopAndDropsTheOldestBeyondTheLimit()
    {
        var history = Create(maxItems: 2);
        var changes = new List<HistoryChange>();
        history.Changed += (_, c) => changes.Add(c);

        history.Add(ClipboardContent.FromText("a"), ItemMetadata.None);
        history.Add(ClipboardContent.FromText("b"), ItemMetadata.None);
        history.Add(ClipboardContent.FromText("c"), ItemMetadata.None);

        Assert.Equal(new[] { "c", "b" }, Texts(history));
        Assert.False(history.ContainsContent(ClipboardContent.FromText("a").Hash));
        Assert.IsType<HistoryChange.Deleted>(changes[^1]);
        Assert.Equal(history.Items.Select(i => i.Id), repository.Index.Select(i => i.Id));
    }

    [Fact]
    public void LoweringTheLimitDeletesTheOldest()
    {
        var history = Create();
        foreach (var text in new[] { "a", "b", "c" })
        {
            history.Add(ClipboardContent.FromText(text), ItemMetadata.None);
        }

        history.SetMaxItems(1);

        Assert.Equal(new[] { "c" }, Texts(history));
        Assert.Single(repository.Contents);
    }

    [Fact]
    public void TracksContentForDuplicates()
    {
        var history = Create();
        var a = ClipboardContent.FromText("a");
        history.Add(a, ItemMetadata.None);
        var second = history.Add(a, ItemMetadata.None);

        history.Delete(second.Id);

        Assert.True(history.ContainsContent(a.Hash));
        Assert.Equal(0, history.IndexOfContent(a.Hash));
        history.Clear();
        Assert.False(history.ContainsContent(a.Hash));
        Assert.Empty(repository.Contents);
    }

    [Fact]
    public void MovesItems()
    {
        var history = Create();
        foreach (var text in new[] { "a", "b", "c" })
        {
            history.Add(ClipboardContent.FromText(text), ItemMetadata.None);
        }

        history.Move(2, 0);

        Assert.Equal(new[] { "a", "c", "b" }, Texts(history));
    }

    [Fact]
    public void UpdatesMetadataOnlyWhenItChanges()
    {
        var history = Create();
        var item = history.Add(ClipboardContent.FromText("a"), ItemMetadata.None);
        var changes = 0;
        history.Changed += (_, _) => changes++;

        history.UpdateMetadata(item.Id, m => m with { Title = "Name" });
        history.UpdateMetadata(item.Id, m => m with { Title = "Name" });

        Assert.Equal("Name", history.Items[0].Metadata.Title);
        Assert.Equal("Name", repository.Index[0].Metadata.Title);
        Assert.Equal(1, changes);
    }

    [Fact]
    public void ReplacingKeepsThePlaceAndMetadataUnderANewId()
    {
        var history = Create();
        var old = history.Add(ClipboardContent.FromText("old"), new ItemMetadata { Title = "Kept" });
        history.Add(ClipboardContent.FromText("top"), ItemMetadata.None);

        var replaced = history.Replace(old.Id, ClipboardContent.FromText("new"))!;

        Assert.NotEqual(old.Id, replaced.Id);
        Assert.Equal(new[] { "top", "new" }, Texts(history));
        Assert.Equal("Kept", replaced.Metadata.Title);
        Assert.False(repository.Contents.ContainsKey(old.Id));
        Assert.False(history.ContainsContent(old.ContentHash));
    }

    [Fact]
    public void DeletesManyAtOnce()
    {
        var history = Create();
        foreach (var text in new[] { "keep", "drop1", "drop2" })
        {
            history.Add(ClipboardContent.FromText(text), ItemMetadata.None);
        }
        var changes = new List<HistoryChange>();
        history.Changed += (_, c) => changes.Add(c);

        var deleted = history.DeleteWhere(i => i.PlainText!.StartsWith("drop"));

        Assert.Equal(2, deleted.Count);
        Assert.Equal(new[] { "keep" }, Texts(history));
        Assert.Single(changes);
    }
}
