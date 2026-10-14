using System.Text;

namespace Yippy.Domain.Text;

/// <summary>
/// Extracts the text from RTF, for items that were copied with styling but without plain text.
/// </summary>
/// <remarks>
/// A small reader rather than a full RTF parser: it keeps the characters of the body (including <c>\'hh</c> and <c>\uN</c>
/// escapes), turns paragraph and line breaks into newlines, and skips destinations such as the font table and pictures.
/// </remarks>
public static class RtfText
{
    /// <summary>Destinations whose content is never text.</summary>
    private static readonly HashSet<string> SkippedDestinations = new(StringComparer.Ordinal)
    {
        "fonttbl", "colortbl", "stylesheet", "info", "pict", "object", "header", "footer", "headerl", "headerr",
        "headerf", "footerl", "footerr", "footerf", "themedata", "colorschememapping", "latentstyles", "datastore",
        "xmlnstbl", "listtable", "listoverridetable", "rsidtbl", "generator", "mmathPr", "pgdsctbl", "filetbl",
        "revtbl", "fldinst", "listtext", "pntext", "pntxta", "pntxtb", "bkmkstart", "bkmkend", "nonshppict",
    };

    static RtfText()
    {
        // Windows code pages such as 1252, which RTF uses for \'hh escapes
        Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);
    }

    public static string ToPlainText(byte[] rtf)
    {
        return ToPlainText(Encoding.Latin1.GetString(rtf));
    }

    public static string ToPlainText(string rtf)
    {
        var output = new StringBuilder();
        var pendingBytes = new List<byte>();
        var encoding = Encoding.GetEncoding(1252);

        // Per group: whether its content is skipped, and how many characters follow a \uN escape (\ucN)
        var stack = new Stack<(bool skip, int unicodeSkip)>();
        var skip = false;
        var unicodeSkip = 1;
        var charsToSkip = 0;
        var i = 0;

        void FlushBytes()
        {
            if (pendingBytes.Count > 0)
            {
                output.Append(encoding.GetString(pendingBytes.ToArray()));
                pendingBytes.Clear();
            }
        }

        void Append(string s)
        {
            FlushBytes();
            if (!skip)
            {
                output.Append(s);
            }
        }

        while (i < rtf.Length)
        {
            var c = rtf[i];
            if (c == '{')
            {
                FlushBytes();
                stack.Push((skip, unicodeSkip));
                i++;
                // {\* ...} marks a destination a reader may ignore
                if (i + 1 < rtf.Length && rtf[i] == '\\' && rtf[i + 1] == '*')
                {
                    skip = true;
                    i += 2;
                }
                continue;
            }
            if (c == '}')
            {
                FlushBytes();
                if (stack.Count > 0)
                {
                    (skip, unicodeSkip) = stack.Pop();
                }
                i++;
                continue;
            }
            if (c == '\\')
            {
                i++;
                if (i >= rtf.Length)
                {
                    break;
                }
                var next = rtf[i];
                if (next is '\\' or '{' or '}')
                {
                    if (!SkipFallbackChar(ref charsToSkip))
                    {
                        Append(next.ToString());
                    }
                    i++;
                    continue;
                }
                if (next == '\'')
                {
                    // \'hh: a byte in the document's code page
                    if (i + 2 < rtf.Length && byte.TryParse(rtf.AsSpan(i + 1, 2), System.Globalization.NumberStyles.HexNumber, null, out var b))
                    {
                        if (!SkipFallbackChar(ref charsToSkip) && !skip)
                        {
                            pendingBytes.Add(b);
                        }
                    }
                    i += 3;
                    continue;
                }
                if (next == '~')
                {
                    Append(" ");
                    i++;
                    continue;
                }
                if (next == '_')
                {
                    Append("‑");
                    i++;
                    continue;
                }
                if (next is '-' or '\r' or '\n')
                {
                    if (next != '-')
                    {
                        Append("\n");
                    }
                    i++;
                    continue;
                }
                if (!char.IsAsciiLetter(next))
                {
                    i++;
                    continue;
                }

                // A control word, optionally followed by a number and one space
                var start = i;
                while (i < rtf.Length && char.IsAsciiLetter(rtf[i]))
                {
                    i++;
                }
                var word = rtf[start..i];
                int? parameter = null;
                var numberStart = i;
                if (i < rtf.Length && (rtf[i] == '-' || char.IsAsciiDigit(rtf[i])))
                {
                    i++;
                    while (i < rtf.Length && char.IsAsciiDigit(rtf[i]))
                    {
                        i++;
                    }
                    if (int.TryParse(rtf.AsSpan(numberStart, i - numberStart), out var n))
                    {
                        parameter = n;
                    }
                }
                if (i < rtf.Length && rtf[i] == ' ')
                {
                    i++;
                }
                HandleControlWord(word, parameter);
                continue;
            }
            if (c is '\r' or '\n')
            {
                i++;
                continue;
            }
            if (!SkipFallbackChar(ref charsToSkip))
            {
                Append(c.ToString());
            }
            i++;
        }
        FlushBytes();
        return output.ToString().TrimEnd('\n');

        void HandleControlWord(string word, int? parameter)
        {
            if (SkippedDestinations.Contains(word))
            {
                skip = true;
                return;
            }
            switch (word)
            {
                case "par":
                case "line":
                case "sect":
                case "page":
                case "row":
                    Append("\n");
                    break;
                case "tab":
                case "cell":
                    Append("\t");
                    break;
                case "emdash":
                    Append("—");
                    break;
                case "endash":
                    Append("–");
                    break;
                case "bullet":
                    Append("•");
                    break;
                case "lquote":
                    Append("‘");
                    break;
                case "rquote":
                    Append("’");
                    break;
                case "ldblquote":
                    Append("“");
                    break;
                case "rdblquote":
                    Append("”");
                    break;
                case "uc":
                    unicodeSkip = parameter ?? 1;
                    break;
                case "u" when parameter is { } code:
                    // Negative values are UTF-16 code units written as signed 16-bit numbers
                    Append(((char)(code < 0 ? code + 65536 : code)).ToString());
                    charsToSkip = unicodeSkip;
                    break;
                case "ansicpg" when parameter is { } codePage:
                    FlushBytes();
                    try
                    {
                        encoding = Encoding.GetEncoding(codePage);
                    }
                    catch (Exception e) when (e is ArgumentException or NotSupportedException)
                    {
                        // Keep the default
                    }
                    break;
            }
        }
    }

    /// <summary>After <c>\uN</c>, the next characters are a fallback for readers without Unicode and are skipped.</summary>
    private static bool SkipFallbackChar(ref int charsToSkip)
    {
        if (charsToSkip > 0)
        {
            charsToSkip--;
            return true;
        }
        return false;
    }
}
