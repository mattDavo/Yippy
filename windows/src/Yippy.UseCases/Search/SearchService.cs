using System.Collections.Concurrent;
using Yippy.Domain.History;
using Yippy.Domain.Search;
using Yippy.UseCases.Abstractions;

namespace Yippy.UseCases.Search;

/// <summary>
/// Fuzzy searches the plain text, name and image text of history items off the UI thread, filtered by kind and source app
/// (see <see cref="SearchQuery"/>).
/// </summary>
/// <remarks>
/// Each item's folded text is read once and cached by item id, so searching again after the history changes only reads the new items.
/// </remarks>
public sealed class SearchService
{
    private readonly IAppInfoProvider appInfo;
    private readonly ConcurrentDictionary<Guid, string?> texts = new();

    public SearchService(IAppInfoProvider appInfo)
    {
        this.appInfo = appInfo;
    }

    /// <summary>Searches <paramref name="items"/> for <paramref name="query"/>. Call on the UI thread.</summary>
    /// <returns>The matching items, in their original order.</returns>
    public Task<IReadOnlyList<HistoryItem>> SearchAsync(string query, IReadOnlyList<HistoryItem> items, CancellationToken cancellationToken)
    {
        var parsed = SearchQuery.Parse(query);
        var needle = FuzzyMatch.Fold(parsed.Text);
        // Metadata changes on the UI thread, so take a copy for the search
        var snapshot = items.Select(i => (Item: i, Metadata: i.Metadata)).ToList();
        var appNames = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        if (parsed.Apps.Count > 0)
        {
            foreach (var source in snapshot.Select(s => s.Metadata.Source).OfType<Domain.Apps.AppIdentity>().Distinct())
            {
                appNames[source.Id] = appInfo.GetDisplayName(source);
            }
        }

        return Task.Run<IReadOnlyList<HistoryItem>>(() =>
        {
            var matches = new List<HistoryItem>();
            foreach (var (item, metadata) in snapshot)
            {
                cancellationToken.ThrowIfCancellationRequested();
                if (Matches(item, metadata, parsed, needle, appNames))
                {
                    matches.Add(item);
                }
            }
            ForgetItemsNotIn(snapshot.Select(s => s.Item.Id));
            return matches;
        }, cancellationToken);
    }

    private bool Matches(HistoryItem item, ItemMetadata metadata, SearchQuery query, string needle, IReadOnlyDictionary<string, string> appNames)
    {
        if (query.Kinds.Count > 0 && !query.Kinds.Contains(item.Kind))
        {
            return false;
        }
        if (query.Apps.Count > 0)
        {
            var source = metadata.Source;
            var name = source is null ? null : appNames.GetValueOrDefault(source.Id);
            if (source is null || !query.MatchesApp(name, source.Id))
            {
                return false;
            }
        }
        if (needle.Length == 0)
        {
            return true;
        }
        return Contains(TextOf(item), needle)
            || Contains(Fold(metadata.Title), needle)
            || Contains(Fold(metadata.RecognizedText), needle);
    }

    private static string? Fold(string? text) => text is null ? null : FuzzyMatch.Fold(text);

    private static bool Contains(string? foldedText, string needle)
    {
        return foldedText is not null && FuzzyMatch.IsSubsequence(needle, foldedText);
    }

    /// <summary>The folded searchable text of the item: its unstyled text, or the paths of its files.</summary>
    private string? TextOf(HistoryItem item)
    {
        return texts.GetOrAdd(item.Id, _ =>
        {
            var text = item.GetUnstyledText();
            if (text is null)
            {
                var files = item.GetFilePaths();
                text = files.Count > 0 ? string.Join('\n', files) : null;
            }
            return text is null ? null : FuzzyMatch.Fold(text);
        });
    }

    private void ForgetItemsNotIn(IEnumerable<Guid> ids)
    {
        if (texts.Count < 2 * Math.Max(ids.Count(), 100))
        {
            return;
        }
        var keep = ids.ToHashSet();
        foreach (var id in texts.Keys.Where(id => !keep.Contains(id)))
        {
            texts.TryRemove(id, out _);
        }
    }
}
