namespace Yippy.App.Shell;

/// <summary>
/// Keeps one copy of Yippy running per user. Later launches don't start another copy: they ask the running one to show
/// its panel, or to quit (the installer does that before replacing Yippy.exe).
/// </summary>
public sealed class SingleInstance : IDisposable
{
    private readonly Mutex mutex;
    private readonly EventWaitHandle showEvent;
    private readonly EventWaitHandle quitEvent;
    private readonly List<RegisteredWaitHandle> waits = new();
    private bool ownsMutex;

    /// <param name="name">Separates the installed app from development builds.</param>
    public SingleInstance(string name)
    {
        mutex = new Mutex(initiallyOwned: true, $@"Local\{name}.Instance", out var createdNew);
        ownsMutex = createdNew;
        IsFirst = createdNew;
        showEvent = new EventWaitHandle(false, EventResetMode.AutoReset, $@"Local\{name}.Show");
        quitEvent = new EventWaitHandle(false, EventResetMode.AutoReset, $@"Local\{name}.Quit");
    }

    /// <summary>Whether no other copy was running when this one started.</summary>
    public bool IsFirst { get; }

    /// <summary>Asks the running copy to open its panel.</summary>
    public void RequestShow() => showEvent.Set();

    /// <summary>Asks the running copy to quit, and waits until it has.</summary>
    /// <returns>Whether no other copy is running any more.</returns>
    public bool RequestQuit(TimeSpan timeout)
    {
        if (ownsMutex)
        {
            return true;
        }
        quitEvent.Set();
        try
        {
            ownsMutex = mutex.WaitOne(timeout);
        }
        catch (AbandonedMutexException)
        {
            // It ended without letting go of the mutex (e.g. it was killed); the mutex is ours now all the same
            ownsMutex = true;
        }
        return ownsMutex;
    }

    /// <summary>Runs <paramref name="action"/> on a pool thread each time another launch asks to show the panel.</summary>
    public void OnShowRequested(Action action) => Listen(showEvent, action);

    /// <summary>Runs <paramref name="action"/> on a pool thread when another launch asks this copy to quit.</summary>
    public void OnQuitRequested(Action action) => Listen(quitEvent, action);

    /// <summary>Lets go of the mutex. Call it on the thread that created this, so a relaunch can start straight away.</summary>
    public void Dispose()
    {
        waits.ForEach(wait => wait.Unregister(null));
        waits.Clear();
        if (ownsMutex)
        {
            mutex.ReleaseMutex();
            ownsMutex = false;
        }
        mutex.Dispose();
        showEvent.Dispose();
        quitEvent.Dispose();
    }

    private void Listen(WaitHandle handle, Action action)
    {
        waits.Add(ThreadPool.RegisterWaitForSingleObject(handle, (_, _) => action(), null, Timeout.Infinite, executeOnlyOnce: false));
    }
}
