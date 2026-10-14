using Yippy.Domain.History;

namespace Yippy.UseCases.Caching;

/// <summary>Keeps recently read item data in memory (Decorator over the repository's data source).</summary>
public sealed class CachingItemDataSource : IItemDataSource
{
    /// <summary>The default limit, in bytes, for one history's cache.</summary>
    public const long DefaultCapacity = 64L * 1024 * 1024;

    private readonly IItemDataSource inner;
    private readonly LruCache<(Guid ItemId, string Format), byte[]> cache;

    public CachingItemDataSource(IItemDataSource inner, long capacity = DefaultCapacity)
    {
        this.inner = inner;
        cache = new LruCache<(Guid, string), byte[]>(capacity, data => data.Length);
    }

    public byte[]? Read(Guid itemId, string format)
    {
        if (cache.TryGet((itemId, format), out var cached))
        {
            return cached;
        }
        var data = inner.Read(itemId, format);
        if (data is not null)
        {
            cache.Set((itemId, format), data);
        }
        return data;
    }
}
