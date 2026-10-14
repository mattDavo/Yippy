using System.Text;

namespace Yippy.Domain.Clipboard;

/// <summary>Reads the <c>CF_HDROP</c> format: a DROPFILES header followed by a double-null-terminated list of paths.</summary>
public static class FileDropList
{
    private const int HeaderSize = 20;

    public static IReadOnlyList<string> Parse(byte[] data)
    {
        if (data.Length < HeaderSize)
        {
            return Array.Empty<string>();
        }
        var offset = (int)BitConverter.ToUInt32(data, 0);
        var isWide = BitConverter.ToUInt32(data, 16) != 0;
        if (offset < HeaderSize || offset >= data.Length)
        {
            return Array.Empty<string>();
        }
        var encoding = isWide ? Encoding.Unicode : Encoding.Default;
        var text = encoding.GetString(data, offset, data.Length - offset);
        var paths = new List<string>();
        foreach (var path in text.Split('\0'))
        {
            if (path.Length == 0)
            {
                break;
            }
            paths.Add(path);
        }
        return paths;
    }
}
