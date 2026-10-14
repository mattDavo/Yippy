namespace Yippy.Domain.Search;

/// <summary>
/// A search bar query: words to find, plus "/img"-style type filters and "@app" source filters.
/// </summary>
/// <remarks>
/// Items must be one of the filtered kinds (if any), copied from one of the filtered apps (if any), and contain the text.
/// </remarks>
public sealed class SearchQuery
{
    private SearchQuery(string text, IReadOnlySet<ItemKind> kinds, IReadOnlyList<string> apps)
    {
        Text = text;
        Kinds = kinds;
        Apps = apps;
    }

    /// <summary>The words that aren't filters, as typed.</summary>
    public string Text { get; }

    public IReadOnlySet<ItemKind> Kinds { get; }

    /// <summary>Folded app names (without spaces) to match the source app's name or id against.</summary>
    public IReadOnlyList<string> Apps { get; }

    public bool IsEmpty => Text.Length == 0 && Kinds.Count == 0 && Apps.Count == 0;

    public static SearchQuery Parse(string query)
    {
        var words = new List<string>();
        var kinds = new HashSet<ItemKind>();
        var apps = new List<string>();
        foreach (var word in query.Split(' ', StringSplitOptions.RemoveEmptyEntries))
        {
            if (word.Length > 1 && word[0] == '/' && KindForFilter(word[1..]) is { } kind)
            {
                kinds.Add(kind);
            }
            else if (word.Length > 1 && word[0] == '@')
            {
                apps.Add(FuzzyMatch.Fold(word[1..]));
            }
            else
            {
                words.Add(word);
            }
        }
        return new SearchQuery(string.Join(' ', words), kinds, apps);
    }

    private static ItemKind? KindForFilter(string word)
    {
        var lower = word.ToLowerInvariant();
        foreach (var kind in Enum.GetValues<ItemKind>())
        {
            if (kind.FilterWords().Contains(lower))
            {
                return kind;
            }
        }
        return null;
    }

    /// <summary>Whether an app with this name and id passes the app filters.</summary>
    public bool MatchesApp(string? name, string? id)
    {
        if (Apps.Count == 0)
        {
            return true;
        }
        var candidates = new[] { name, id }
            .Where(c => c is not null)
            .Select(c => new string(FuzzyMatch.Fold(c!).Where(ch => !char.IsWhiteSpace(ch)).ToArray()))
            .ToList();
        return Apps.Any(app => candidates.Any(c => c.Contains(app, StringComparison.Ordinal)));
    }

    /// <summary>The text to put in the search bar to show only items copied from this app.</summary>
    public static string AppFilter(string appName)
    {
        return "@" + new string(appName.Where(c => !char.IsWhiteSpace(c)).ToArray());
    }
}
