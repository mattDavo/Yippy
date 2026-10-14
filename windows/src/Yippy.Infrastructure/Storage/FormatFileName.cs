using System.Text;

namespace Yippy.Infrastructure.Storage;

/// <summary>
/// Turns clipboard format names into safe file names and back. Letters, digits, '_' and '-' are kept; every other
/// character is written as %XX bytes of its UTF-8, so names like "Rich Text Format" or "text/html" are safe on any file system.
/// </summary>
public static class FormatFileName
{
    private static readonly HashSet<string> ReservedNames = new(StringComparer.OrdinalIgnoreCase)
    {
        "CON", "PRN", "AUX", "NUL",
        "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
        "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9",
    };

    public static string Encode(string format)
    {
        var builder = new StringBuilder();
        foreach (var b in Encoding.UTF8.GetBytes(format))
        {
            var c = (char)b;
            if (char.IsAsciiLetterOrDigit(c) || c is '_' or '-')
            {
                builder.Append(c);
            }
            else
            {
                builder.Append('%').Append(b.ToString("X2"));
            }
        }
        var name = builder.ToString();
        // Windows doesn't allow files named after devices, so escape the first character of those
        if (ReservedNames.Contains(name))
        {
            name = "%" + ((byte)name[0]).ToString("X2") + name[1..];
        }
        return name;
    }

    public static string Decode(string fileName)
    {
        var bytes = new List<byte>();
        for (var i = 0; i < fileName.Length; i++)
        {
            if (fileName[i] == '%' && i + 2 < fileName.Length
                && byte.TryParse(fileName.AsSpan(i + 1, 2), System.Globalization.NumberStyles.HexNumber, null, out var b))
            {
                bytes.Add(b);
                i += 2;
            }
            else
            {
                bytes.AddRange(Encoding.UTF8.GetBytes(fileName[i].ToString()));
            }
        }
        return Encoding.UTF8.GetString(bytes.ToArray());
    }
}
