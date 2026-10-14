using System.Net;
using System.Text;
using System.Text.RegularExpressions;

namespace Yippy.Domain.Text;

/// <summary>Reads the text of the Windows <c>HTML Format</c>, a header of byte offsets followed by the HTML.</summary>
public static partial class HtmlClipboardText
{
    public static string ToPlainText(byte[] data)
    {
        var raw = Encoding.UTF8.GetString(data);
        var html = Fragment(raw, data) ?? raw;
        html = BlockEnd().Replace(html, "\n");
        html = Tag().Replace(html, string.Empty);
        return WebUtility.HtmlDecode(html).Trim();
    }

    /// <summary>The copied fragment, found from the StartFragment and EndFragment byte offsets in the header.</summary>
    private static string? Fragment(string raw, byte[] data)
    {
        var start = Offset(raw, "StartFragment");
        var end = Offset(raw, "EndFragment");
        if (start is null || end is null || start < 0 || end > data.Length || start > end)
        {
            return null;
        }
        return Encoding.UTF8.GetString(data, start.Value, end.Value - start.Value);
    }

    private static int? Offset(string raw, string key)
    {
        var match = Regex.Match(raw, "^" + key + @":(\d+)", RegexOptions.Multiline);
        return match.Success && int.TryParse(match.Groups[1].Value, out var value) ? value : null;
    }

    [GeneratedRegex(@"<(br|/p|/div|/li|/tr|/h[1-6])\b[^>]*>", RegexOptions.IgnoreCase)]
    private static partial Regex BlockEnd();

    [GeneratedRegex(@"<!--.*?-->|<[^>]+>", RegexOptions.Singleline)]
    private static partial Regex Tag();
}
