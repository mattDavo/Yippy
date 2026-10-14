using System.Collections.Concurrent;
using System.Text.Json;
using Yippy.Domain.Clipboard;
using Yippy.Domain.History;
using Yippy.UseCases.Abstractions;

namespace Yippy.Infrastructure.Storage;

/// <summary>
/// Stores a history in a folder: one sub-folder per item, named by its id, holding one file per clipboard format,
/// plus <c>index.json</c> with the item order, content hashes and metadata.
/// </summary>
/// <remarks>
/// <code>
/// history/
///   index.json
///   3f2b…/CF_UNICODETEXT
///   3f2b…/Rich%20Text%20Format
/// </code>
/// All disk writes run on one background queue. Items being written are served from memory until they are on disk.
/// </remarks>
public sealed class FileHistoryRepository : IHistoryRepository, IDisposable
{
    public const string IndexFileName = "index.json";

    private readonly string directory;
    private readonly IAppLogger logger;
    private readonly SerialWorkQueue queue;
    private readonly ConcurrentDictionary<Guid, ClipboardContent> unwritten = new();
    private readonly object indexGate = new();
    private IReadOnlyList<StoredItem>? unwrittenIndex;

    public FileHistoryRepository(string directory, IAppLogger logger)
    {
        this.directory = directory;
        this.logger = logger;
        queue = new SerialWorkQueue(logger);
    }

    public IReadOnlyList<StoredItem> Load()
    {
        Directory.CreateDirectory(directory);
        var folders = Directory.GetDirectories(directory)
            .Select(Path.GetFileName)
            .Select(name => Guid.TryParse(name, out var id) ? id : (Guid?)null)
            .OfType<Guid>()
            .ToHashSet();

        var items = new List<StoredItem>();
        foreach (var entry in ReadIndex())
        {
            if (!folders.Remove(entry.Id))
            {
                logger.Warning($"Item {entry.Id} is in {IndexFileName} but its folder is missing in {directory}; it was skipped.");
                continue;
            }
            if (ToStoredItem(entry.Id, entry.Formats, entry.ContentHash, entry.Metadata) is { } item)
            {
                items.Add(item);
            }
        }
        // Folders the index doesn't know about, e.g. when Yippy stopped before saving it: keep them at the end
        foreach (var id in folders)
        {
            if (ToStoredItem(id, null, null, null) is { } item)
            {
                logger.Warning($"Item folder {id} in {directory} is not in {IndexFileName}; it was added to the end.");
                items.Add(item);
            }
        }
        return items;
    }

    public byte[]? Read(Guid itemId, string format)
    {
        if (unwritten.TryGetValue(itemId, out var content))
        {
            return content.Get(format);
        }
        try
        {
            return File.ReadAllBytes(DataPath(itemId, format));
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException)
        {
            return null;
        }
    }

    public void Add(Guid id, ClipboardContent content)
    {
        unwritten[id] = content;
        queue.Enqueue(() =>
        {
            // Skip it if it was deleted before it was written
            if (!unwritten.ContainsKey(id))
            {
                return;
            }
            var folder = ItemFolder(id);
            Directory.CreateDirectory(folder);
            foreach (var (format, data) in content.Formats)
            {
                File.WriteAllBytes(Path.Combine(folder, FormatFileName.Encode(format)), data);
            }
            unwritten.TryRemove(id, out _);
        });
    }

    public void Delete(Guid id)
    {
        unwritten.TryRemove(id, out _);
        queue.Enqueue(() => DeleteFolder(id));
    }

    public void DeleteAll()
    {
        unwritten.Clear();
        queue.Enqueue(() =>
        {
            foreach (var folder in Directory.GetDirectories(directory))
            {
                if (Guid.TryParse(Path.GetFileName(folder), out var id))
                {
                    DeleteFolder(id);
                }
            }
        });
    }

    public void SaveIndex(IReadOnlyList<StoredItem> items)
    {
        lock (indexGate)
        {
            var isQueued = unwrittenIndex is not null;
            unwrittenIndex = items;
            if (isQueued)
            {
                // The queued write will save the latest index
                return;
            }
        }
        queue.Enqueue(WriteIndex);
    }

    public Task FlushAsync() => queue.FlushAsync();

    public void Dispose() => queue.Dispose();

    private void WriteIndex()
    {
        IReadOnlyList<StoredItem> items;
        lock (indexGate)
        {
            items = unwrittenIndex ?? Array.Empty<StoredItem>();
            unwrittenIndex = null;
        }
        var entries = items.Select(i => new IndexEntry(i.Id, i.Formats, i.ContentHash, i.Metadata)).ToList();
        JsonDefaults.WriteAtomically(Path.Combine(directory, IndexFileName), entries, typeof(List<IndexEntry>));
    }

    private IReadOnlyList<IndexEntry> ReadIndex()
    {
        var path = Path.Combine(directory, IndexFileName);
        if (!File.Exists(path))
        {
            return Array.Empty<IndexEntry>();
        }
        try
        {
            using var stream = File.OpenRead(path);
            return JsonSerializer.Deserialize<List<IndexEntry>>(stream, JsonDefaults.Options) ?? new List<IndexEntry>();
        }
        catch (Exception e) when (e is JsonException or IOException or UnauthorizedAccessException)
        {
            logger.Error($"Couldn't read {path}; the items will be loaded without their order and metadata.", e);
            return Array.Empty<IndexEntry>();
        }
    }

    /// <summary>The stored item, reading what the index lacks from its folder. Null (and the folder deleted) if it holds no data.</summary>
    private StoredItem? ToStoredItem(Guid id, IReadOnlyList<string>? formats, string? contentHash, ItemMetadata? metadata)
    {
        var folder = ItemFolder(id);
        formats ??= Directory.GetFiles(folder).Select(f => FormatFileName.Decode(Path.GetFileName(f))).ToList();
        if (formats.Count == 0)
        {
            logger.Warning($"Item folder {id} in {directory} is empty; it was deleted.");
            DeleteFolder(id);
            return null;
        }
        if (contentHash is null)
        {
            var data = formats.Select(f => KeyValuePair.Create(f, Read(id, f) ?? Array.Empty<byte>()));
            contentHash = ClipboardContent.ComputeHash(data);
        }
        return new StoredItem(id, formats, contentHash, metadata ?? ItemMetadata.None);
    }

    private void DeleteFolder(Guid id)
    {
        var folder = ItemFolder(id);
        if (Directory.Exists(folder))
        {
            Directory.Delete(folder, recursive: true);
        }
    }

    private string ItemFolder(Guid id) => Path.Combine(directory, id.ToString());

    private string DataPath(Guid id, string format) => Path.Combine(ItemFolder(id), FormatFileName.Encode(format));

    /// <summary>One item in <c>index.json</c>. Everything but the id is optional, so a damaged entry still loads.</summary>
    private sealed record IndexEntry(Guid Id, IReadOnlyList<string>? Formats, string? ContentHash, ItemMetadata? Metadata);
}
