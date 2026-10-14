using System.Globalization;
using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

namespace Yippy.Domain.Transforms;

/// <summary>
/// A change made to an item's text when it is pasted from the right-click menu's "Paste Transformed" submenu.
/// </summary>
/// <remarks>Strategy pattern: each transform is one implementation, listed in <see cref="TextTransforms.All"/>.</remarks>
public interface ITextTransform
{
    string Title { get; }

    /// <returns>The transformed text, or null if this transform doesn't apply to it (e.g. it isn't JSON).</returns>
    string? Apply(string text);
}

public static class TextTransforms
{
    /// <summary>Every transform, in menu order.</summary>
    public static IReadOnlyList<ITextTransform> All { get; } = new ITextTransform[]
    {
        new TrimWhitespace(),
        new Uppercase(),
        new Lowercase(),
        new TitleCase(),
        new RemoveLinkTracking(),
        new PrettyPrintJson(),
    };
}

public sealed class TrimWhitespace : ITextTransform
{
    public string Title => "Trim Whitespace";

    public string? Apply(string text) => text.Trim();
}

public sealed class Uppercase : ITextTransform
{
    public string Title => "UPPERCASE";

    public string? Apply(string text) => text.ToUpper(CultureInfo.CurrentCulture);
}

public sealed class Lowercase : ITextTransform
{
    public string Title => "lowercase";

    public string? Apply(string text) => text.ToLower(CultureInfo.CurrentCulture);
}

public sealed class TitleCase : ITextTransform
{
    public string Title => "Title Case";

    public string? Apply(string text)
    {
        var culture = CultureInfo.CurrentCulture;
        return culture.TextInfo.ToTitleCase(text.ToLower(culture));
    }
}

/// <summary>Removes the query parameters that only exist to track where a link was shared or clicked.</summary>
public sealed partial class RemoveLinkTracking : ITextTransform
{
    public static readonly IReadOnlySet<string> TrackingParameters = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
    {
        "fbclid", "gclid", "gclsrc", "dclid", "msclkid", "yclid", "twclid", "ttclid", "igshid", "li_fat_id",
        "mc_cid", "mc_eid", "_hsenc", "_hsmi", "mkt_tok", "oly_anon_id", "oly_enc_id", "vero_id", "wickedid",
        "ref_src", "ref_url", "s_cid",
    };

    public string Title => "Remove Tracking from Links";

    public string? Apply(string text)
    {
        return Link().Replace(text, match => RemoveTrackingParameters(match.Value) ?? match.Value);
    }

    public static bool IsTrackingParameter(string name)
    {
        return name.StartsWith("utm_", StringComparison.OrdinalIgnoreCase) || TrackingParameters.Contains(name);
    }

    /// <returns>The link without its tracking parameters, or null if it has none. The rest of the link is kept exactly as it was.</returns>
    public static string? RemoveTrackingParameters(string link)
    {
        var queryStart = link.IndexOf('?');
        if (queryStart < 0)
        {
            return null;
        }
        var fragmentStart = link.IndexOf('#', queryStart);
        var queryEnd = fragmentStart < 0 ? link.Length : fragmentStart;
        var parameters = link[(queryStart + 1)..queryEnd].Split('&');
        var kept = parameters.Where(p => !IsTrackingParameter(Uri.UnescapeDataString(p.Split('=')[0]))).ToList();
        if (kept.Count == parameters.Length)
        {
            return null;
        }
        var query = kept.Count > 0 ? "?" + string.Join('&', kept) : string.Empty;
        return link[..queryStart] + query + link[queryEnd..];
    }

    [GeneratedRegex(@"https?://[^\s<>""']+", RegexOptions.IgnoreCase)]
    private static partial Regex Link();
}

/// <summary>Indents JSON objects and arrays, with their keys sorted.</summary>
public sealed class PrettyPrintJson : ITextTransform
{
    private static readonly JsonSerializerOptions Options = new()
    {
        WriteIndented = true,
        Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
    };

    public string Title => "Pretty-Print JSON";

    public string? Apply(string text)
    {
        JsonNode? node;
        try
        {
            node = JsonNode.Parse(text.Trim());
        }
        catch (JsonException)
        {
            return null;
        }
        if (node is not (JsonObject or JsonArray))
        {
            return null;
        }
        return Sorted(node)!.ToJsonString(Options);
    }

    private static JsonNode? Sorted(JsonNode? node) => node switch
    {
        JsonObject obj => new JsonObject(obj
            .OrderBy(p => p.Key, StringComparer.Ordinal)
            .Select(p => KeyValuePair.Create(p.Key, Sorted(p.Value)))),
        JsonArray array => new JsonArray(array.Select(Sorted).ToArray()),
        _ => node?.DeepClone(),
    };
}
