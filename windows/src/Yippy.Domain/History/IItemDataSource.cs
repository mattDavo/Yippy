namespace Yippy.Domain.History;

/// <summary>Where the bytes of stored items are read from, so items can load them lazily.</summary>
public interface IItemDataSource
{
    /// <returns>The data of one format of an item, or null if it can't be read. Must be safe to call from any thread.</returns>
    byte[]? Read(Guid itemId, string format);
}
