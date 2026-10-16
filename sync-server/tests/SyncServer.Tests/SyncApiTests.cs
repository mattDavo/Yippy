using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using SyncServer.Application;

namespace SyncServer.Tests;

public class SyncApiTests
{
    private static readonly byte[] A = { 1, 2, 3 };
    private static readonly byte[] B = { 4, 5 };

    [Fact]
    public async Task StoredRecordsComeBackAsChanges()
    {
        using var server = new TestServer();
        var space = server.Space();

        Assert.Equal(1, await space.PutOkAsync("h/one", A));
        Assert.Equal(2, await space.PutOkAsync("f/two", B));

        var page = await space.ChangesAsync();
        Assert.Equal(new[] { "h/one", "f/two" }, page.Changes.Select(c => c.Key));
        Assert.Equal(A, page.Changes[0].Data);
        Assert.Equal(2, page.Cursor);
        Assert.False(page.More);
        Assert.Empty((await space.ChangesAsync(since: 2)).Changes);
    }

    [Fact]
    public async Task OnlyTheLatestChangeOfARecordIsSent()
    {
        using var server = new TestServer();
        var space = server.Space();
        await space.PutOkAsync("h/one", A);
        await space.PutOkAsync("h/two", A);
        (await space.DeleteAsync("h/one")).EnsureSuccessStatusCode();

        var page = await space.ChangesAsync();

        Assert.Equal(new[] { "h/two", "h/one" }, page.Changes.Select(c => c.Key));
        Assert.True(page.Changes[1].Deleted);
        Assert.Null(page.Changes[1].Data);
    }

    [Fact]
    public async Task OnlyTheFirstTokenMayUseASpace()
    {
        using var server = new TestServer();
        await server.Space(token: "first").PutOkAsync("h/one", A);
        var other = server.Space(token: "second");

        Assert.Equal(HttpStatusCode.Unauthorized, (await other.PutAsync("h/one", B)).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await other.ChangesResponseAsync(0)).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await other.DeleteSpaceAsync()).StatusCode);
        Assert.Single((await server.Space(token: "first").ChangesAsync()).Changes);
    }

    [Fact]
    public async Task AnUnknownSpaceHasNoChanges()
    {
        using var server = new TestServer();

        var page = await server.Space().ChangesAsync();

        Assert.Empty(page.Changes);
        Assert.False(page.Reset);
    }

    [Theory]
    [InlineData("/v1/spaces/NOT-HEX/changes")]
    [InlineData("/v1/spaces/0123456789abcdef0123456789abcdef/records/x/one")]
    [InlineData("/v1/spaces/0123456789abcdef0123456789abcdef/records/h/bad.id")]
    public async Task MalformedRequestsAreRefused(string path)
    {
        using var server = new TestServer();
        var client = server.Space().Http;

        var response = path.Contains("/records/")
            ? await client.PutAsync(path, new ByteArrayContent(A))
            : await client.GetAsync(path);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task RequestsWithoutATokenAreRefused()
    {
        using var server = new TestServer();
        var client = server.CreateClient();

        var response = await client.GetAsync("/v1/spaces/0123456789abcdef0123456789abcdef/changes");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task ClearingDeletesEveryRecordOfTheKind()
    {
        using var server = new TestServer();
        var space = server.Space();
        await space.PutOkAsync("h/one", A);
        await space.PutOkAsync("h/two", A);
        await space.PutOkAsync("f/fav", A);

        (await space.ClearAsync("h")).EnsureSuccessStatusCode();

        var changes = (await space.ChangesAsync(since: 3)).Changes;
        Assert.Equal(new[] { "h/one", "h/two" }, changes.Select(c => c.Key));
        Assert.All(changes, c => Assert.True(c.Deleted));
        Assert.Equal(new[] { 4L, 5L }, changes.Select(c => c.Seq));
    }

    [Fact]
    public async Task ChangesComeInPages()
    {
        using var server = new TestServer(new ServerOptions { MaxChangesPerPage = 2 });
        var space = server.Space();
        for (var i = 0; i < 5; i++)
        {
            await space.PutOkAsync($"h/item{i}", A);
        }

        var first = await space.ChangesAsync();
        var second = await space.ChangesAsync(first.Cursor);
        var third = await space.ChangesAsync(second.Cursor);

        Assert.Equal(new[] { "h/item0", "h/item1" }, first.Changes.Select(c => c.Key));
        Assert.True(first.More);
        Assert.Equal(new[] { "h/item2", "h/item3" }, second.Changes.Select(c => c.Key));
        Assert.Equal(new[] { "h/item4" }, third.Changes.Select(c => c.Key));
        Assert.False(third.More);
    }

    [Fact]
    public async Task APageStopsAtItsSizeButHoldsAtLeastOneChange()
    {
        using var server = new TestServer(new ServerOptions { MaxPageBytes = 4 });
        var space = server.Space();
        await space.PutOkAsync("h/big", new byte[10]);
        await space.PutOkAsync("h/small", A);

        var first = await space.ChangesAsync();

        Assert.Equal(new[] { "h/big" }, first.Changes.Select(c => c.Key));
        Assert.True(first.More);
        Assert.Equal(new[] { "h/small" }, (await space.ChangesAsync(first.Cursor)).Changes.Select(c => c.Key));
    }

    [Fact]
    public async Task AWaitingRequestAnswersAsSoonAsSomethingChanges()
    {
        using var server = new TestServer();
        var space = server.Space();
        await space.PutOkAsync("h/one", A);

        var waiting = space.ChangesAsync(since: 1, wait: 30);
        await Task.Delay(200);
        Assert.False(waiting.IsCompleted);
        await space.PutOkAsync("h/two", B);

        var page = await waiting.WaitAsync(TimeSpan.FromSeconds(10));
        Assert.Equal("h/two", Assert.Single(page.Changes).Key);
    }

    [Fact]
    public async Task TheAccessKeyIsNeededWhenTheServerHasOne()
    {
        using var server = new TestServer(new ServerOptions { AccessKey = "secret" });

        var health = await server.CreateClient().GetFromJsonAsync<JsonElement>("/v1/health");
        Assert.True(health.GetProperty("accessKeyRequired").GetBoolean());
        Assert.Equal(HttpStatusCode.Forbidden, (await server.Space().PutAsync("h/one", A)).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await server.Space(accessKey: "wrong").PutAsync("h/one", A)).StatusCode);
        Assert.Equal(1, await server.Space(accessKey: "secret").PutOkAsync("h/one", A));
    }

    [Fact]
    public async Task RecordsOverTheLimitAreRefused()
    {
        using var server = new TestServer(new ServerOptions { MaxRecordBytes = 8 });

        var response = await server.Space().PutAsync("h/big", new byte[9]);

        Assert.Equal(HttpStatusCode.RequestEntityTooLarge, response.StatusCode);
    }

    [Fact]
    public async Task AFullSpaceDropsItsOldestHistoryButKeepsFavourites()
    {
        using var server = new TestServer(new ServerOptions { SpaceQuotaBytes = 25 });
        var space = server.Space();
        await space.PutOkAsync("f/fav", new byte[10]);
        await space.PutOkAsync("h/old", new byte[10]);
        server.Clock.Now += TimeSpan.FromMinutes(1);
        await space.PutOkAsync("h/new", new byte[10]);

        var keys = (await space.ChangesAsync()).Changes.Select(c => c.Key);

        Assert.Equal(new[] { "f/fav", "h/new" }, keys);
    }

    [Fact]
    public async Task OldHistoryIsDroppedAndOldDeletionsForgotten()
    {
        using var server = new TestServer(new ServerOptions
        {
            HistoryRetention = TimeSpan.FromDays(30),
            DeletionRetention = TimeSpan.FromDays(10),
        });
        var space = server.Space();
        await space.PutOkAsync("h/old", A);
        await space.PutOkAsync("f/fav", A);
        await space.PutOkAsync("h/gone", A);
        (await space.DeleteAsync("h/gone")).EnsureSuccessStatusCode();
        server.Clock.Now += TimeSpan.FromDays(31);
        await space.PutOkAsync("h/new", A);

        await server.Retention.RunOnceAsync(CancellationToken.None);

        Assert.Equal(new[] { "f/fav", "h/new" }, (await space.ChangesAsync()).Changes.Select(c => c.Key));
        // A device that last synced before the forgotten deletion must start again
        Assert.True((await space.ChangesAsync(since: 2)).Reset);
        Assert.False((await space.ChangesAsync(since: 4)).Reset);
    }

    [Fact]
    public async Task ADeletedSpaceTellsDevicesToStartAgain()
    {
        using var server = new TestServer();
        var space = server.Space();
        await space.PutOkAsync("h/one", A);

        Assert.Equal(HttpStatusCode.NoContent, (await space.DeleteSpaceAsync()).StatusCode);

        Assert.True((await space.ChangesAsync(since: 1)).Reset);
        Assert.Empty((await space.ChangesAsync()).Changes);
        // Another key can claim it now
        Assert.Equal(1, await server.Space(token: "token-b").PutOkAsync("h/one", A));
    }
}
