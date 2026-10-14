using System.Threading.Channels;
using Yippy.UseCases.Abstractions;

namespace Yippy.Infrastructure.Storage;

/// <summary>Runs work one item at a time, in order, on a background thread, so disk writes never block the UI.</summary>
public sealed class SerialWorkQueue : IDisposable
{
    private readonly Channel<Action> channel = Channel.CreateUnbounded<Action>(new UnboundedChannelOptions { SingleReader = true });
    private readonly IAppLogger logger;
    private readonly Task worker;

    public SerialWorkQueue(IAppLogger logger)
    {
        this.logger = logger;
        worker = Task.Run(RunAsync);
    }

    public void Enqueue(Action work)
    {
        if (!channel.Writer.TryWrite(work))
        {
            logger.Warning("Work was queued after the queue was stopped, so it was skipped.");
        }
    }

    /// <summary>Completes once everything queued before it has run.</summary>
    public Task FlushAsync()
    {
        var done = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        if (!channel.Writer.TryWrite(() => done.SetResult()))
        {
            done.SetResult();
        }
        return done.Task;
    }

    /// <summary>Stops taking work and waits a few seconds for what's queued to finish.</summary>
    public void Dispose()
    {
        channel.Writer.TryComplete();
        worker.Wait(TimeSpan.FromSeconds(5));
    }

    private async Task RunAsync()
    {
        await foreach (var work in channel.Reader.ReadAllAsync())
        {
            try
            {
                work();
            }
            catch (Exception e)
            {
                logger.Error("A background write failed.", e);
            }
        }
    }
}
