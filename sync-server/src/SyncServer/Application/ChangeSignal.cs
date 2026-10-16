using System.Collections.Concurrent;
using SyncServer.Domain;

namespace SyncServer.Application;

/// <summary>
/// Wakes requests waiting for a space's next change (Observer pattern). Only within this process, which is enough for
/// one server.
/// </summary>
public sealed class ChangeSignal
{
    private readonly ConcurrentDictionary<SpaceId, TaskCompletionSource> waiting = new();

    /// <summary>Completes on the space's next change. Get it before checking for changes, so none is missed in between.</summary>
    public Task NextChange(SpaceId space)
    {
        return waiting.GetOrAdd(space, _ => new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously)).Task;
    }

    public void Notify(SpaceId space)
    {
        if (waiting.TryRemove(space, out var source))
        {
            source.TrySetResult();
        }
    }
}
