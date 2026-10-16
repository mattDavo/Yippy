using System.Net;
using System.Text;
using System.Text.RegularExpressions;

namespace Yippy.Domain.Text;

/// <summary>Reads and writes the Windows <c>HTML Format</c>, a header of byte offsets followed by the HTML.</summary>
public static partial class HtmlClipboardText
{
    /// <summary>The copied HTML without the header: the fragment if the header marks one, else everything after the header.</summary>
    public static string GetFragment(byte[] data)
    {
        var raw = Encoding.UTF8.GetString(data);
        if (Fragment(raw, data) is { } fragment)
        {
            return fragment;
        }
        var start = Offset(raw, "StartHTML");
        return start is { } s && s >= 0 && s <= data.Length ? Encoding.UTF8.GetString(data, s, data.Length - s).TrimEnd('\0') : raw.TrimEnd('\0');
    }

    /// <summary>Wraps an HTML fragment in the <c>HTML Format</c> header, as apps expect it on the clipboard.</summary>
    public static byte[] Wrap(string fragment)
    {
        const string header = "Version:0.9\r\nStartHTML:{0:D10}\r\nEndHTML:{1:D10}\r\nStartFragment:{2:D10}\r\nEndFragment:{3:D10}\r\n";
        const string before = "<html><body>\r\n<!--StartFragment-->";
        const string after = "<!--EndFragment-->\r\n</body></html>";
        var headerLength = string.Format(header, 0, 0, 0, 0).Length;
        var startFragment = headerLength + Encoding.UTF8.GetByteCount(before);
        var endFragment = startFragment + Encoding.UTF8.GetByteCount(fragment);
        var endHtml = endFragment + Encoding.UTF8.GetByteCount(after);
        return Encoding.UTF8.GetBytes(string.Format(header, headerLength, endHtml, startFragment, endFragment) + before + fragment + after);
    }

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
