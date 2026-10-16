using System.Security.Cryptography;
using System.Text;
using SyncServer.Application;
using SyncServer.Domain;

namespace SyncServer.Api;

/// <summary>The HTTP API of PROTOCOL.md, mapped onto <see cref="SyncService"/>.</summary>
public static class SyncEndpoints
{
    public static void MapSyncEndpoints(this IEndpointRouteBuilder app, ServerOptions options)
    {
        app.MapGet("/v1/health", () => Results.Json(new { ok = true, accessKeyRequired = options.AccessKey is not null }));

        var spaces = app.MapGroup("/v1/spaces/{space}").AddEndpointFilter(new AccessKeyFilter(options.AccessKey));

        spaces.MapPut("/records/{kind}/{id}", async (string space, string kind, string id, HttpRequest request, SyncService sync, CancellationToken ct) =>
        {
            if (Parse(space, request) is not var (spaceId, token) || !RecordKey.TryParse(kind, id, out var key))
            {
                return BadRequest();
            }
            if (request.ContentLength > options.MaxRecordBytes)
            {
                return Error(StatusCodes.Status413PayloadTooLarge, "The record is too large.");
            }
            using var body = new MemoryStream();
            await request.Body.CopyToAsync(body, ct);
            return Results.Json(new { seq = await sync.PutAsync(spaceId, token, key, body.ToArray(), ct) });
        });

        spaces.MapDelete("/records/{kind}/{id}", async (string space, string kind, string id, HttpRequest request, SyncService sync, CancellationToken ct) =>
        {
            if (Parse(space, request) is not var (spaceId, token) || !RecordKey.TryParse(kind, id, out var key))
            {
                return BadRequest();
            }
            return Results.Json(new { seq = await sync.DeleteAsync(spaceId, token, key, ct) });
        });

        spaces.MapPost("/clear/{kind}", async (string space, string kind, HttpRequest request, SyncService sync, CancellationToken ct) =>
        {
            if (Parse(space, request) is not var (spaceId, token) || !RecordKinds.TryParse(kind, out var recordKind))
            {
                return BadRequest();
            }
            return Results.Json(new { seq = await sync.ClearAsync(spaceId, token, recordKind, ct) });
        });

        spaces.MapGet("/changes", async (string space, long? since, int? wait, HttpRequest request, SyncService sync, CancellationToken ct) =>
        {
            if (Parse(space, request) is not var (spaceId, token) || since < 0)
            {
                return BadRequest();
            }
            var page = await sync.GetChangesAsync(spaceId, token, since ?? 0, TimeSpan.FromSeconds(Math.Max(wait ?? 0, 0)), ct);
            return Results.Json(new
            {
                changes = page.Changes.Select(c => new { key = c.Key, seq = c.Seq, deleted = c.IsDeleted, data = c.Data }),
                cursor = page.Cursor,
                more = page.More,
                reset = page.Reset,
            });
        });

        spaces.MapDelete("", async (string space, HttpRequest request, SyncService sync, CancellationToken ct) =>
        {
            if (Parse(space, request) is not var (spaceId, token))
            {
                return BadRequest();
            }
            await sync.DeleteSpaceAsync(spaceId, token, ct);
            return Results.NoContent();
        });
    }

    /// <summary>Turns refused requests into error responses.</summary>
    public static async Task HandleSyncErrors(HttpContext context, Func<Task> next)
    {
        try
        {
            await next();
        }
        catch (SyncException e)
        {
            var status = e.Error switch
            {
                SyncError.Unauthorized => StatusCodes.Status401Unauthorized,
                SyncError.TooLarge => StatusCodes.Status413PayloadTooLarge,
                _ => StatusCodes.Status400BadRequest,
            };
            await Error(status, e.Message).ExecuteAsync(context);
        }
        catch (BadHttpRequestException e) when (e.StatusCode == StatusCodes.Status413PayloadTooLarge)
        {
            await Error(e.StatusCode, "The record is too large.").ExecuteAsync(context);
        }
    }

    private static (SpaceId Space, string Token)? Parse(string space, HttpRequest request)
    {
        var authorization = request.Headers.Authorization.ToString();
        const string bearer = "Bearer ";
        if (!SpaceId.TryParse(space, out var spaceId) || !authorization.StartsWith(bearer, StringComparison.Ordinal))
        {
            return null;
        }
        var token = authorization[bearer.Length..].Trim();
        return token.Length is > 0 and <= 256 ? (spaceId, token) : null;
    }

    private static IResult BadRequest() => Error(StatusCodes.Status400BadRequest, "Malformed request or missing auth token.");

    private static IResult Error(int status, string message) => Results.Json(new { error = message }, statusCode: status);

    /// <summary>Refuses requests without the server's access key, when it has one.</summary>
    private sealed class AccessKeyFilter : IEndpointFilter
    {
        private readonly byte[]? accessKey;

        public AccessKeyFilter(string? accessKey)
        {
            this.accessKey = accessKey is null ? null : Encoding.UTF8.GetBytes(accessKey);
        }

        public ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext context, EndpointFilterDelegate next)
        {
            if (accessKey is not null)
            {
                var given = Encoding.UTF8.GetBytes(context.HttpContext.Request.Headers["X-Access-Key"].ToString());
                if (!CryptographicOperations.FixedTimeEquals(given, accessKey))
                {
                    return ValueTask.FromResult<object?>(Error(StatusCodes.Status403Forbidden, "This server needs its access key."));
                }
            }
            return next(context);
        }
    }
}
