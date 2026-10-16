using Yippy.Domain.Clipboard;
using Yippy.Domain.History;
using Yippy.Domain.Sync;
using Yippy.UseCases.Abstractions;
using Yippy.UseCases.History;
using Yippy.UseCases.Settings;

namespace Yippy.UseCases.Sync;

public enum SyncStatusKind
{
    Off,
    Connecting,
    UpToDate,

    /// <summary>The server can't be reached; changes wait and are sent when it can.</summary>
    Offline,

    /// <summary>The server refuses the access key or sync key; nothing syncs until the settings change.</summary>
    Refused,
}

public sealed record SyncStatus(SyncStatusKind Kind, string? Message = null, DateTimeOffset? LastSynced = null)
{
    public static SyncStatus Off { get; } = new(SyncStatusKind.Off);
}

/// <summary>
/// Syncs the clipboard history and favourites with the user's other devices through the sync server
/// (sync-server/PROTOCOL.md).
/// </summary>
/// <remarks>
/// Sends what the user does (<see cref="IHistoryActivity"/>): copies, deletions and favourites, never trimming or
/// automatic cleaning, and never copies from apps whose items expire. Keeps a queue of changes to send, so nothing is
/// lost while offline, and waits on the server for other devices' changes (long polling), applying them straight to the
/// histories. Use from the UI thread: the loop's awaits come back to it.
/// </remarks>
public sealed class SyncService : IHistoryActivity, IDisposable
{
    /// <summary>How many of the newest history items are sent when sync is turned on (all favourites are).</summary>
    public const int ExistingHistorySent = 50;

    private static readonly TimeSpan LongPollWait = TimeSpan.FromSeconds(25);
    private static readonly TimeSpan MaxRetryDelay = TimeSpan.FromMinutes(1);

    private readonly ItemHistory history;
    private readonly ItemHistory favourites;
    private readonly SettingsService settings;
    private readonly ISyncKeyStore keys;
    private readonly ISyncStateRepository stateRepository;
    private readonly ISyncServerFactory servers;
    private readonly SyncFormatMapper mapper;
    private readonly IClock clock;
    private readonly IAppLogger logger;

    private readonly Dictionary<Guid, string> recordIds;
    private readonly List<PendingSyncChange> pending;
    private SyncKey? key;
    private long cursor;
    private bool sentExistingItems;
    private ISyncServer? server;
    private SyncConnection? connection;
    private CancellationTokenSource? running;
    private CancellationTokenSource? waiting;

    public SyncService(
        ItemHistory history,
        ItemHistory favourites,
        SettingsService settings,
        ISyncKeyStore keys,
        ISyncStateRepository stateRepository,
        ISyncServerFactory servers,
        SyncFormatMapper mapper,
        IClock clock,
        IAppLogger logger)
    {
        this.history = history;
        this.favourites = favourites;
        this.settings = settings;
        this.keys = keys;
        this.stateRepository = stateRepository;
        this.servers = servers;
        this.mapper = mapper;
        this.clock = clock;
        this.logger = logger;

        key = keys.Load();
        var state = stateRepository.Load();
        recordIds = new Dictionary<Guid, string>(state.RecordIds);
        pending = state.Pending.ToList();
        cursor = state.Cursor;
        sentExistingItems = state.SentExistingItems;
        if (key is not null && state.SpaceId != key.SpaceId)
        {
            ResetState();
        }
        settings.Changed += (_, e) =>
        {
            if (e.Old.SyncEnabled != e.Current.SyncEnabled || e.Old.SyncServer != e.Current.SyncServer
                || e.Old.SyncAccessKey != e.Current.SyncAccessKey)
            {
                Reconnect();
            }
        };
        connection = CurrentConnection();
    }

    public event EventHandler? StatusChanged;

    public SyncStatus Status { get; private set; } = SyncStatus.Off;

    /// <summary>The sync key, to show so it can be entered on other devices. Null until sync is set up.</summary>
    public SyncKey? Key => key;

    /// <summary>Whether sync is turned on with a server and key. Changes are only queued then.</summary>
    public bool IsEnabled => connection is not null;

    /// <summary>Changes waiting to be sent.</summary>
    public IReadOnlyList<PendingSyncChange> Pending => pending;

    /// <summary>Starts syncing in the background if it's turned on. Call once, on the UI thread.</summary>
    public void Start() => Reconnect();

    /// <summary>Turns sync on with this server and key, or changes them.</summary>
    /// <param name="server">The server's address; https unless it's this computer.</param>
    public void TurnOn(Uri server, string? accessKey, SyncKey newKey)
    {
        if (!Equals(key, newKey))
        {
            keys.Save(newKey);
            key = newKey;
            ResetState();
            SaveState();
        }
        var trimmedAccessKey = string.IsNullOrWhiteSpace(accessKey) ? null : accessKey.Trim();
        var before = connection;
        settings.Update(s => s with { SyncEnabled = true, SyncServer = server.ToString(), SyncAccessKey = trimmedAccessKey });
        // A new key on the same server doesn't change the settings, so their Changed event doesn't reconnect
        if (connection == before)
        {
            Reconnect();
        }
    }

    public void TurnOff() => settings.Update(s => s with { SyncEnabled = false });

    /// <summary>Deletes everything this sync key stored on the server, then turns sync off and forgets the key.</summary>
    public async Task EraseServerDataAsync(CancellationToken cancellationToken = default)
    {
        if (connection is { } current)
        {
            using var target = servers.Create(current);
            await target.DeleteSpaceAsync(cancellationToken);
        }
        TurnOff();
        keys.Save(null);
        key = null;
        ResetState();
        SaveState();
    }

    public void Dispose()
    {
        Stop();
    }

    // MARK: - What the user did

    public void Copied(HistoryItem item)
    {
        if (IsEnabled && !IsFromExpiringApp(item))
        {
            QueuePut(SyncRecordKind.History, history, item);
        }
    }

    public void Deleted(ItemHistory from, IReadOnlyList<HistoryItem> items)
    {
        if (!IsEnabled)
        {
            return;
        }
        var kind = KindOf(from);
        foreach (var item in items)
        {
            if (RecordIdOf(item) is { } id)
            {
                Queue(new PendingSyncChange(SyncOperation.Delete, kind, id));
            }
            recordIds.Remove(item.Id);
        }
    }

    public void Cleared(ItemHistory from)
    {
        if (IsEnabled)
        {
            Queue(new PendingSyncChange(SyncOperation.Clear, KindOf(from)));
        }
    }

    public void FavouriteChanged(HistoryItem favourite, HistoryItem? replaced = null)
    {
        if (!IsEnabled)
        {
            return;
        }
        if (replaced is not null && RecordIdOf(replaced) is { } oldId)
        {
            recordIds.Remove(replaced.Id);
            Queue(new PendingSyncChange(SyncOperation.Delete, SyncRecordKind.Favourite, oldId));
        }
        QueuePut(SyncRecordKind.Favourite, favourites, favourite);
    }

    // MARK: - Syncing

    /// <summary>
    /// Sends the waiting changes, then applies other devices' changes, waiting up to <paramref name="wait"/> for some if
    /// there are none. The background loop repeats this; tests call it directly.
    /// </summary>
    public async Task SyncOnceAsync(TimeSpan wait, CancellationToken cancellationToken)
    {
        if (connection is not { } current)
        {
            return;
        }
        server ??= servers.Create(current);
        QueueExistingItems();
        await SendPendingAsync(server, cancellationToken);
        await ReceiveAsync(server, wait, cancellationToken);
    }

    private async Task RunAsync(CancellationToken stopping)
    {
        var delay = TimeSpan.FromSeconds(2);
        SetStatus(new SyncStatus(SyncStatusKind.Connecting));
        while (!stopping.IsCancellationRequested)
        {
            waiting = CancellationTokenSource.CreateLinkedTokenSource(stopping);
            try
            {
                await SyncOnceAsync(pending.Count > 0 ? TimeSpan.Zero : LongPollWait, waiting.Token);
                SetStatus(new SyncStatus(SyncStatusKind.UpToDate, null, clock.Now));
                delay = TimeSpan.FromSeconds(2);
            }
            catch (OperationCanceledException) when (!stopping.IsCancellationRequested)
            {
                // A change was queued while waiting for the server; send it now
            }
            catch (SyncServerException e) when (!stopping.IsCancellationRequested)
            {
                var refused = e.Error is SyncServerError.AccessKeyRefused or SyncServerError.KeyRefused;
                SetStatus(new SyncStatus(refused ? SyncStatusKind.Refused : SyncStatusKind.Offline, e.Message, Status.LastSynced));
                try
                {
                    await Task.Delay(refused ? MaxRetryDelay : delay, waiting.Token);
                }
                catch (OperationCanceledException) when (!stopping.IsCancellationRequested)
                {
                }
                delay = TimeSpan.FromTicks(Math.Min(delay.Ticks * 2, MaxRetryDelay.Ticks));
            }
            catch (OperationCanceledException)
            {
                return;
            }
            catch (Exception e)
            {
                // A bug; keep syncing rather than take the app down, but don't spin
                logger.Error("Sync failed unexpectedly.", e);
                SetStatus(new SyncStatus(SyncStatusKind.Offline, e.Message, Status.LastSynced));
                await Task.Delay(MaxRetryDelay, stopping).ContinueWith(_ => { }, TaskScheduler.Current);
            }
            finally
            {
                waiting.Dispose();
                waiting = null;
            }
        }
    }

    private async Task SendPendingAsync(ISyncServer target, CancellationToken cancellationToken)
    {
        while (pending.Count > 0)
        {
            var change = pending[0];
            try
            {
                await SendAsync(target, change, cancellationToken);
            }
            catch (SyncServerException e) when (e.Error == SyncServerError.Rejected)
            {
                // E.g. an image over the server's size limit: retrying won't help
                logger.Warning($"The sync server refused a change ({change.Operation} {change.Kind}): {e.Message}");
            }
            pending.RemoveAt(0);
            SaveState();
        }
    }

    private async Task SendAsync(ISyncServer target, PendingSyncChange change, CancellationToken cancellationToken)
    {
        switch (change.Operation)
        {
            case SyncOperation.Clear:
                await target.ClearAsync(change.Kind, cancellationToken);
                break;
            case SyncOperation.Delete:
                await target.DeleteAsync(new SyncRecordKey(change.Kind, change.RecordId!), cancellationToken);
                break;
            case SyncOperation.Put:
                var from = change.Kind == SyncRecordKind.History ? history : favourites;
                var index = from.IndexOf(change.ItemId!.Value);
                // The item may have been deleted since; then there's nothing to send
                if (index < 0 || key is null || from.Items[index].ReadContent() is not { } content)
                {
                    return;
                }
                var item = from.Items[index];
                var syncContent = mapper.ToSync(content);
                if (syncContent.IsEmpty)
                {
                    return;
                }
                var recordKey = new SyncRecordKey(change.Kind, change.RecordId!);
                var payload = new SyncPayload(syncContent, item.Metadata.CopiedAt ?? clock.Now,
                    change.Kind == SyncRecordKind.Favourite ? item.Metadata.Title : null);
                await target.PutAsync(recordKey, SyncRecordCodec.Seal(payload, recordKey, key), cancellationToken);
                break;
        }
    }

    private async Task ReceiveAsync(ISyncServer target, TimeSpan wait, CancellationToken cancellationToken)
    {
        while (true)
        {
            var page = await target.GetChangesAsync(cursor, wait, cancellationToken);
            if (page.Reset)
            {
                cursor = 0;
                wait = TimeSpan.Zero;
                continue;
            }
            foreach (var change in page.Changes)
            {
                Apply(change);
            }
            cursor = page.Cursor;
            SaveState();
            if (!page.More)
            {
                return;
            }
            wait = TimeSpan.Zero;
        }
    }

    /// <summary>Applies another device's change to the histories, without queuing anything to send back.</summary>
    private void Apply(SyncChange change)
    {
        if (key is null || SyncRecordKey.TryParse(change.Key) is not { } recordKey)
        {
            return;
        }
        var target = recordKey.Kind == SyncRecordKind.History ? history : favourites;
        var local = FindLocal(target, recordKey.Id);
        if (change.Data is null)
        {
            if (local is not null)
            {
                target.Delete(local.Id);
                recordIds.Remove(local.Id);
            }
            return;
        }
        if (SyncRecordCodec.Open(change.Data, recordKey, key) is not { } payload)
        {
            logger.Warning($"Couldn't read the synced record {change.Key}; it may be from a newer version.");
            return;
        }
        if (recordKey.Kind == SyncRecordKind.History)
        {
            ApplyHistory(recordKey, payload, local);
        }
        else
        {
            ApplyFavourite(recordKey, payload, local);
        }
    }

    private void ApplyHistory(SyncRecordKey recordKey, SyncPayload payload, HistoryItem? local)
    {
        if (local is not null)
        {
            // Copied again on another device: move it to where its new copy time puts it
            if (local.Metadata.CopiedAt is { } localCopiedAt && localCopiedAt >= payload.CopiedAt)
            {
                return;
            }
            var from = history.IndexOf(local.Id);
            var to = InsertionIndex(history.Items.Where(i => i.Id != local.Id), payload.CopiedAt);
            history.Move(from, to);
            history.UpdateMetadata(local.Id, m => m with { CopiedAt = payload.CopiedAt });
            return;
        }
        var content = mapper.ToClipboard(payload.Content);
        var index = InsertionIndex(history.Items, payload.CopiedAt);
        // Older than everything a full history keeps
        if (content.IsEmpty || index >= history.MaxItems)
        {
            return;
        }
        var item = history.Add(content, new ItemMetadata { CopiedAt = payload.CopiedAt }, index);
        recordIds[item.Id] = recordKey.Id;
    }

    private void ApplyFavourite(SyncRecordKey recordKey, SyncPayload payload, HistoryItem? local)
    {
        if (local is not null)
        {
            if (local.Metadata.Title != payload.Title)
            {
                favourites.UpdateMetadata(local.Id, m => m with { Title = payload.Title });
            }
            return;
        }
        var content = mapper.ToClipboard(payload.Content);
        if (content.IsEmpty)
        {
            return;
        }
        var item = favourites.Add(content, new ItemMetadata { CopiedAt = payload.CopiedAt, Title = payload.Title });
        recordIds[item.Id] = recordKey.Id;
    }

    /// <summary>The first index whose item was copied before <paramref name="copiedAt"/>; items with no date count as oldest.</summary>
    private static int InsertionIndex(IEnumerable<HistoryItem> items, DateTimeOffset copiedAt)
    {
        var index = 0;
        foreach (var item in items)
        {
            if ((item.Metadata.CopiedAt ?? DateTimeOffset.MinValue) < copiedAt)
            {
                return index;
            }
            index++;
        }
        return index;
    }

    /// <summary>The local item with this record id: one it was given, or one whose content gives it.</summary>
    private HistoryItem? FindLocal(ItemHistory target, string recordId)
    {
        foreach (var item in target.Items)
        {
            if (RecordIdOf(item) == recordId)
            {
                return item;
            }
        }
        return null;
    }

    /// <summary>The item's record id, worked out from its content the first time. Null if it has nothing to sync.</summary>
    private string? RecordIdOf(HistoryItem item)
    {
        if (recordIds.TryGetValue(item.Id, out var known))
        {
            return known.Length == 0 ? null : known;
        }
        if (key is null || item.ReadContent() is not { } content)
        {
            return null;
        }
        var syncContent = mapper.ToSync(content);
        // Kinds share ids; the kind is only in the key's prefix
        var id = syncContent.IsEmpty ? string.Empty : SyncRecordKey.For(SyncRecordKind.History, syncContent, key).Id;
        recordIds[item.Id] = id;
        return id.Length == 0 ? null : id;
    }

    private void QueuePut(SyncRecordKind kind, ItemHistory from, HistoryItem item)
    {
        if (RecordIdOf(item) is not { } id)
        {
            return;
        }
        if (pending.Any(p => p.Operation == SyncOperation.Put && p.Kind == kind && p.ItemId == item.Id))
        {
            return;
        }
        Queue(new PendingSyncChange(SyncOperation.Put, kind, id, item.Id));
    }

    private void Queue(PendingSyncChange change)
    {
        pending.Add(change);
        SaveState();
        // Stop waiting for the server's changes and send this one
        waiting?.Cancel();
    }

    /// <summary>Once per sync key: sends the favourites and newest history items that were here before sync.</summary>
    private void QueueExistingItems()
    {
        if (sentExistingItems)
        {
            return;
        }
        sentExistingItems = true;
        foreach (var item in history.Items.Take(ExistingHistorySent).Where(i => !IsFromExpiringApp(i)).Reverse())
        {
            QueuePut(SyncRecordKind.History, history, item);
        }
        foreach (var favourite in favourites.Items.Reverse())
        {
            QueuePut(SyncRecordKind.Favourite, favourites, favourite);
        }
        SaveState();
    }

    private bool IsFromExpiringApp(HistoryItem item)
    {
        return item.Metadata.Source is { } source && settings.Current.ExpiringApps.Contains(source);
    }

    private SyncRecordKind KindOf(ItemHistory target) => target == favourites ? SyncRecordKind.Favourite : SyncRecordKind.History;

    private SyncConnection? CurrentConnection()
    {
        var current = settings.Current;
        if (!current.SyncEnabled || key is null || !Uri.TryCreate(current.SyncServer, UriKind.Absolute, out var uri))
        {
            return null;
        }
        return new SyncConnection(uri, current.SyncAccessKey, key);
    }

    private void Reconnect()
    {
        Stop();
        connection = CurrentConnection();
        if (connection is null)
        {
            SetStatus(SyncStatus.Off);
            return;
        }
        running = new CancellationTokenSource();
        _ = RunAsync(running.Token);
    }

    private void Stop()
    {
        running?.Cancel();
        running?.Dispose();
        running = null;
        server?.Dispose();
        server = null;
    }

    private void ResetState()
    {
        recordIds.Clear();
        pending.Clear();
        cursor = 0;
        sentExistingItems = false;
    }

    private void SaveState()
    {
        // Forget the ids of items that are gone
        var live = history.Items.Select(i => i.Id).Concat(favourites.Items.Select(i => i.Id)).ToHashSet();
        foreach (var id in recordIds.Keys.Where(id => !live.Contains(id)).ToList())
        {
            recordIds.Remove(id);
        }
        stateRepository.Save(new SyncState
        {
            SpaceId = key?.SpaceId,
            Cursor = cursor,
            SentExistingItems = sentExistingItems,
            RecordIds = new Dictionary<Guid, string>(recordIds),
            Pending = pending.ToList(),
        });
    }

    private void SetStatus(SyncStatus status)
    {
        if (status == Status)
        {
            return;
        }
        Status = status;
        StatusChanged?.Invoke(this, EventArgs.Empty);
    }
}
