using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using SyncServer.Application;

namespace SyncServer.Infrastructure;

/// <summary>Every hour, drops old history records and forgets old deletions (see <see cref="ServerOptions"/>).</summary>
public sealed class RetentionWorker : BackgroundService
{
    private readonly ISyncStore store;
    private readonly ServerOptions options;
    private readonly TimeProvider time;
    private readonly ILogger<RetentionWorker> logger;

    public RetentionWorker(ISyncStore store, ServerOptions options, TimeProvider time, ILogger<RetentionWorker> logger)
    {
        this.store = store;
        this.options = options;
        this.time = time;
        this.logger = logger;
    }

    public Task RunOnceAsync(CancellationToken cancellationToken)
    {
        var now = time.GetUtcNow();
        return store.ApplyRetentionAsync(now - options.HistoryRetention, now - options.DeletionRetention, cancellationToken);
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromHours(1), time);
        do
        {
            try
            {
                await RunOnceAsync(stoppingToken);
            }
            catch (Exception e) when (e is not OperationCanceledException)
            {
                logger.LogError(e, "Applying retention failed");
            }
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }
}
