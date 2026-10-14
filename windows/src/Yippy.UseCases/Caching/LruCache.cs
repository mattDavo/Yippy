namespace Yippy.UseCases.Caching;

/// <summary>A thread-safe least-recently-used cache limited by the total size of its values.</summary>
public sealed class LruCache<TKey, TValue>
    where TKey : notnull
{
    private readonly object gate = new();
    private readonly Dictionary<TKey, LinkedListNode<(TKey Key, TValue Value, long Size)>> nodes = new();
    private readonly LinkedList<(TKey Key, TValue Value, long Size)> recency = new();
    private readonly Func<TValue, long> sizeOf;
    private long size;

    public LruCache(long capacity, Func<TValue, long> sizeOf)
    {
        Capacity = capacity;
        this.sizeOf = sizeOf;
    }

    public long Capacity { get; }

    public long Size
    {
        get
        {
            lock (gate)
            {
                return size;
            }
        }
    }

    public bool TryGet(TKey key, out TValue value)
    {
        lock (gate)
        {
            if (nodes.TryGetValue(key, out var node))
            {
                recency.Remove(node);
                recency.AddFirst(node);
                value = node.Value.Value;
                return true;
            }
        }
        value = default!;
        return false;
    }

    /// <summary>Adds or replaces a value, then evicts the least recently used values until the cache fits. Values larger than the cache are not kept.</summary>
    public void Set(TKey key, TValue value)
    {
        var valueSize = sizeOf(value);
        lock (gate)
        {
            RemoveLocked(key);
            if (valueSize > Capacity)
            {
                return;
            }
            nodes[key] = recency.AddFirst((key, value, valueSize));
            size += valueSize;
            while (size > Capacity && recency.Last is { } last)
            {
                RemoveLocked(last.Value.Key);
            }
        }
    }

    public void Remove(TKey key)
    {
        lock (gate)
        {
            RemoveLocked(key);
        }
    }

    private void RemoveLocked(TKey key)
    {
        if (nodes.Remove(key, out var node))
        {
            recency.Remove(node);
            size -= node.Value.Size;
        }
    }
}
