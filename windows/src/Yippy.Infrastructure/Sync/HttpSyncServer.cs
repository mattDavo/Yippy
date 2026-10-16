using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Yippy.Domain.Sync;
using Yippy.UseCases.Sync;

namespace Yippy.Infrastructure.Sync;

/// <summary>Talks to the sync server over HTTP (sync-server/PROTOCOL.md).</summary>
public sealed class HttpSyncServer : ISyncServer
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    private readonly HttpClient http;
    private readonly string space;

    /// <param name="handler">For tests; the default handler otherwise.</param>
    public HttpSyncServer(SyncConnection connection, HttpMessageHandler? handler = null)
    {
        var baseAddress = connection.Server.ToString();
        http = handler is null ? new HttpClient() : new HttpClient(handler);
        http.BaseAddress = new Uri(baseAddress.EndsWith('/') ? baseAddress : baseAddress + "/");
        // Requests for changes wait on the server for up to a minute
        http.Timeout = TimeSpan.FromSeconds(100);
        http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", connection.Key.AuthToken);
        if (connection.AccessKey is { } accessKey)
        {
            http.DefaultRequestHeaders.Add("X-Access-Key", accessKey);
        }
        space = connection.Key.SpaceId;
    }

    public Task PutAsync(SyncRecordKey key, byte[] data, CancellationToken cancellationToken)
    {
        var content = new ByteArrayContent(data);
        content.Headers.ContentType = new MediaTypeHeaderValue("application/octet-stream");
        return SendAsync(HttpMethod.Put, $"v1/spaces/{space}/records/{key}", content, cancellationToken);
    }

    public Task DeleteAsync(SyncRecordKey key, CancellationToken cancellationToken)
    {
        return SendAsync(HttpMethod.Delete, $"v1/spaces/{space}/records/{key}", null, cancellationToken);
    }

    public Task ClearAsync(SyncRecordKind kind, CancellationToken cancellationToken)
    {
        return SendAsync(HttpMethod.Post, $"v1/spaces/{space}/clear/{SyncRecordKey.PrefixOf(kind)}", null, cancellationToken);
    }

    public Task DeleteSpaceAsync(CancellationToken cancellationToken)
    {
        return SendAsync(HttpMethod.Delete, $"v1/spaces/{space}", null, cancellationToken);
    }

    public async Task<SyncChangePage> GetChangesAsync(long since, TimeSpan wait, CancellationToken cancellationToken)
    {
        var path = $"v1/spaces/{space}/changes?since={since}&wait={(int)wait.TotalSeconds}";
        using var response = await SendAsync(HttpMethod.Get, path, null, cancellationToken, keepResponse: true);
        PageJson? page;
        try
        {
            page = await response!.Content.ReadFromJsonAsync<PageJson>(Json, cancellationToken);
        }
        catch (JsonException e)
        {
            throw new SyncServerException(SyncServerError.Unreachable, "The sync server sent something unexpected. Is the address right?", e);
        }
        if (page?.Changes is null)
        {
            throw new SyncServerException(SyncServerError.Unreachable, "The sync server sent something unexpected. Is the address right?");
        }
        var changes = page.Changes
            .Where(c => c.Key is not null)
            .Select(c => new SyncChange(c.Key!, c.Seq, c.Deleted ? null : c.Data ?? Array.Empty<byte>()))
            .ToList();
        return new SyncChangePage(changes, page.Cursor, page.More, page.Reset);
    }

    public void Dispose() => http.Dispose();

    private async Task<HttpResponseMessage?> SendAsync(HttpMethod method, string path, HttpContent? content, CancellationToken cancellationToken,
        bool keepResponse = false)
    {
        HttpResponseMessage response;
        try
        {
            using var request = new HttpRequestMessage(method, path) { Content = content };
            response = await http.SendAsync(request, cancellationToken);
        }
        catch (HttpRequestException e)
        {
            throw new SyncServerException(SyncServerError.Unreachable, "Can't reach the sync server.", e);
        }
        catch (TaskCanceledException e) when (!cancellationToken.IsCancellationRequested)
        {
            throw new SyncServerException(SyncServerError.Unreachable, "The sync server didn't answer in time.", e);
        }
        if (response.IsSuccessStatusCode)
        {
            if (keepResponse)
            {
                return response;
            }
            response.Dispose();
            return null;
        }
        using (response)
        {
            var message = await ErrorMessageAsync(response, cancellationToken);
            throw response.StatusCode switch
            {
                HttpStatusCode.Unauthorized => new SyncServerException(SyncServerError.KeyRefused,
                    "The server has this space under another sync key."),
                HttpStatusCode.Forbidden => new SyncServerException(SyncServerError.AccessKeyRefused,
                    "The server refused the access key."),
                HttpStatusCode.NotFound => new SyncServerException(SyncServerError.Unreachable,
                    "There's no sync server at that address."),
                var status when (int)status >= 500 => new SyncServerException(SyncServerError.Unreachable,
                    $"The sync server had a problem ({(int)status})."),
                _ => new SyncServerException(SyncServerError.Rejected, message ?? $"The sync server refused the request ({(int)response.StatusCode})."),
            };
        }
    }

    private static async Task<string?> ErrorMessageAsync(HttpResponseMessage response, CancellationToken cancellationToken)
    {
        try
        {
            var error = await response.Content.ReadFromJsonAsync<ErrorJson>(Json, cancellationToken);
            return error?.Error;
        }
        catch (Exception e) when (e is JsonException or NotSupportedException or InvalidOperationException)
        {
            return null;
        }
    }

    private sealed record ChangeJson(string? Key, long Seq, bool Deleted, byte[]? Data);

    private sealed record PageJson(List<ChangeJson>? Changes, long Cursor, bool More, bool Reset);

    private sealed record ErrorJson(string? Error);
}

/// <summary>Makes <see cref="HttpSyncServer"/>s.</summary>
public sealed class HttpSyncServerFactory : ISyncServerFactory
{
    public ISyncServer Create(SyncConnection connection) => new HttpSyncServer(connection);
}
