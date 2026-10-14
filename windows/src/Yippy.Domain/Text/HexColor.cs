using System.Globalization;

namespace Yippy.Domain.Text;

/// <summary>An sRGB colour written as hex, like <c>#f80</c>, <c>#ff8800</c> or <c>#ff8800cc</c>.</summary>
public readonly record struct HexColor(byte R, byte G, byte B, byte A)
{
    public static bool TryParse(string text, out HexColor color)
    {
        color = default;
        var hex = text.Trim();
        if (!hex.StartsWith('#'))
        {
            return false;
        }
        hex = hex[1..];
        if (hex.Length is 3 or 4)
        {
            hex = string.Concat(hex.Select(c => new string(c, 2)));
        }
        if (hex.Length is not (6 or 8) || !uint.TryParse(hex, NumberStyles.HexNumber, CultureInfo.InvariantCulture, out var value))
        {
            return false;
        }
        if (hex.Length == 6)
        {
            value = (value << 8) | 0xFF;
        }
        color = new HexColor((byte)(value >> 24), (byte)(value >> 16), (byte)(value >> 8), (byte)value);
        return true;
    }
}
