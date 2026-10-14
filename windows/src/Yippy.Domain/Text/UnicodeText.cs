using System.Text;

namespace Yippy.Domain.Text;

/// <summary>Reads and writes the <c>CF_UNICODETEXT</c> format: null-terminated UTF-16LE.</summary>
public static class UnicodeText
{
    public static string Decode(byte[] data)
    {
        var text = Encoding.Unicode.GetString(data, 0, data.Length - data.Length % 2);
        var end = text.IndexOf('\0');
        return end >= 0 ? text[..end] : text;
    }

    public static byte[] Encode(string text)
    {
        return Encoding.Unicode.GetBytes(text + "\0");
    }
}
