namespace Yippy.Domain.Clipboard;

/// <summary>Turns a <c>CF_DIB</c>/<c>CF_DIBV5</c> (a bitmap without its file header) into a .bmp file image decoders can read.</summary>
public static class DibImage
{
    private const int FileHeaderSize = 14;
    private const uint BiBitfields = 3;
    private const uint BiAlphaBitfields = 6;

    /// <returns>The .bmp file bytes, or null if the data is too short to be a bitmap.</returns>
    public static byte[]? ToBmpFile(byte[] dib)
    {
        if (dib.Length < 16)
        {
            return null;
        }
        var headerSize = BitConverter.ToUInt32(dib, 0);
        if (headerSize < 12 || headerSize > dib.Length)
        {
            return null;
        }

        var colorTableSize = 0u;
        if (headerSize >= 40)
        {
            var bitCount = BitConverter.ToUInt16(dib, 14);
            var compression = BitConverter.ToUInt32(dib, 16);
            var colorsUsed = BitConverter.ToUInt32(dib, 32);
            if (colorsUsed != 0)
            {
                colorTableSize = colorsUsed * 4;
            }
            else if (bitCount <= 8)
            {
                colorTableSize = (1u << bitCount) * 4;
            }
            // A plain BITMAPINFOHEADER is followed by its colour masks; the larger headers hold them
            if (headerSize == 40 && compression == BiBitfields)
            {
                colorTableSize += 12;
            }
            else if (headerSize == 40 && compression == BiAlphaBitfields)
            {
                colorTableSize += 16;
            }
        }
        else
        {
            // BITMAPCOREHEADER: 3-byte colour table entries
            var bitCount = BitConverter.ToUInt16(dib, 10);
            if (bitCount <= 8)
            {
                colorTableSize = (1u << bitCount) * 3;
            }
        }

        var file = new byte[FileHeaderSize + dib.Length];
        file[0] = (byte)'B';
        file[1] = (byte)'M';
        BitConverter.TryWriteBytes(file.AsSpan(2), (uint)file.Length);
        BitConverter.TryWriteBytes(file.AsSpan(10), FileHeaderSize + headerSize + colorTableSize);
        dib.CopyTo(file, FileHeaderSize);
        return file;
    }
}
