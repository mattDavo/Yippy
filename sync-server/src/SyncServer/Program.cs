using SyncServer.Api;
using SyncServer.Application;
using SyncServer.Infrastructure;

// Composition root: reads the settings, wires the store into the service and maps the API.
var builder = WebApplication.CreateBuilder(args);
var options = ServerOptions.FromEnvironment(Environment.GetEnvironmentVariable);
builder.WebHost.ConfigureKestrel(k => k.Limits.MaxRequestBodySize = options.MaxRecordBytes + 1024);
builder.Services.AddSingleton(options);
builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddSingleton<ISyncStore>(s => new SqliteSyncStore(s.GetRequiredService<ServerOptions>().DatabasePath));
builder.Services.AddSingleton<ChangeSignal>();
builder.Services.AddSingleton<SyncService>();
builder.Services.AddHostedService<RetentionWorker>();

var app = builder.Build();
app.Use(SyncEndpoints.HandleSyncErrors);
app.MapSyncEndpoints(app.Services.GetRequiredService<ServerOptions>());
app.Run();

/// <summary>Lets the tests start the server (WebApplicationFactory).</summary>
public partial class Program
{
}
