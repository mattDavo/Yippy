using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using SyncServer.Application;
using SyncServer.Infrastructure;

namespace SyncServer.Tests;

/// <summary>A clock the tests move by hand.</summary>
public sealed class ManualClock : TimeProvider
{
    public DateTimeOffset Now { get; set; } = new(2026, 10, 1, 12, 0, 0, TimeSpan.Zero);

    public override DateTimeOffset GetUtcNow() => Now;
}

/// <summary>The server in memory, with its database in a temporary file.</summary>
public sealed class TestServer : WebApplicationFactory<Program>
{
    private readonly string directory = Path.Combine(Path.GetTempPath(), "sync-server-tests", Guid.NewGuid().ToString("N"));

    public TestServer(ServerOptions? options = null)
    {
        Options = (options ?? new ServerOptions()) with { DatabasePath = Path.Combine(directory, "sync.db") };
    }

    public ServerOptions Options { get; }

    public ManualClock Clock { get; } = new();

    public ISyncStore Store => Services.GetRequiredService<ISyncStore>();

    public RetentionWorker Retention => Services.GetServices<IHostedService>().OfType<RetentionWorker>().Single();

    /// <summary>A client of one space, as a device with this space id and auth token would be.</summary>
    public SpaceClient Space(string space = "0123456789abcdef0123456789abcdef", string token = "token-a", string? accessKey = null)
    {
        var client = CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        if (accessKey is not null)
        {
            client.DefaultRequestHeaders.Add("X-Access-Key", accessKey);
        }
        return new SpaceClient(client, space);
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureTestServices(services =>
        {
            services.AddSingleton(Options);
            services.AddSingleton<TimeProvider>(Clock);
            services.AddSingleton<ISyncStore>(new SqliteSyncStore(Options.DatabasePath));
        });
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools();
        try
        {
            Directory.Delete(directory, recursive: true);
        }
        catch (IOException)
        {
        }
    }
}

public sealed record ChangeDto(string Key, long Seq, bool Deleted, byte[]? Data);

public sealed record PageDto(List<ChangeDto> Changes, long Cursor, bool More, bool Reset);

public sealed class SpaceClient
{
    public SpaceClient(HttpClient http, string space)
    {
        Http = http;
        Space = space;
    }

    public HttpClient Http { get; }

    public string Space { get; }

    public Task<HttpResponseMessage> PutAsync(string key, byte[] data)
    {
        return Http.PutAsync($"/v1/spaces/{Space}/records/{key}", new ByteArrayContent(data));
    }

    public Task<HttpResponseMessage> DeleteAsync(string key) => Http.DeleteAsync($"/v1/spaces/{Space}/records/{key}");

    public Task<HttpResponseMessage> ClearAsync(string kind) => Http.PostAsync($"/v1/spaces/{Space}/clear/{kind}", null);

    public Task<HttpResponseMessage> DeleteSpaceAsync() => Http.DeleteAsync($"/v1/spaces/{Space}");

    public Task<HttpResponseMessage> ChangesResponseAsync(long since, int wait = 0)
    {
        return Http.GetAsync($"/v1/spaces/{Space}/changes?since={since}&wait={wait}");
    }

    public async Task<PageDto> ChangesAsync(long since = 0, int wait = 0)
    {
        var response = await ChangesResponseAsync(since, wait);
        response.EnsureSuccessStatusCode();
        return (await response.Content.ReadFromJsonAsync<PageDto>(new JsonSerializerOptions(JsonSerializerDefaults.Web)))!;
    }

    public async Task<long> PutOkAsync(string key, byte[] data)
    {
        var response = await PutAsync(key, data);
        response.EnsureSuccessStatusCode();
        return (await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("seq").GetInt64();
    }
}
