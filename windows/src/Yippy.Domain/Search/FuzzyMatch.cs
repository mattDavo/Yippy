namespace Yippy.Domain.Search;

/// <summary>The case-insensitive subsequence match search uses: the query's characters must appear in order, not necessarily together.</summary>
public static class FuzzyMatch
{
    /// <summary>Normalises text so a plain character comparison is case insensitive. Fold each string once and reuse it.</summary>
    public static string Fold(string text) => text.ToLowerInvariant();

    /// <summary>Whether the characters of <paramref name="needle"/> appear in <paramref name="haystack"/> in order. Both should already be folded.</summary>
    public static bool IsSubsequence(string needle, string haystack)
    {
        var h = 0;
        foreach (var n in needle)
        {
            while (h < haystack.Length && haystack[h] != n)
            {
                h++;
            }
            if (h == haystack.Length)
            {
                return false;
            }
            h++;
        }
        return true;
    }

    public static bool Matches(string query, string text) => IsSubsequence(Fold(query), Fold(text));
}
