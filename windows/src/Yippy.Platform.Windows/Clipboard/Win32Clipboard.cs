using System.Runtime.InteropServices;
using System.Text;
using Yippy.Domain.Clipboard;
using Yippy.Platform.Windows.Apps;
using Yippy.Platform.Windows.Native;
using Yippy.UseCases.Abstractions;
using static Yippy.Platform.Windows.Native.NativeMethods;

namespace Yippy.Platform.Windows.Clipboard;

/// <summary>
/// The Windows clipboard through the Win32 API, reading and writing every memory-based format byte for byte.
/// </summary>
/// <remarks>
/// GDI handle formats (bitmaps, metafiles, palettes) and formats Windows synthesizes from others (ANSI text, locale, bitmap)
/// are skipped: Windows recreates them from the stored formats when the item is pasted. Use from the UI thread.
/// </remarks>
public sealed class Win32Clipboard : IClipboard
{
    /// <summary>Formats larger than this are not kept, so one huge copy can't exhaust memory.</summary>
    private const long MaxFormatSize = 256L * 1024 * 1024;

    private const uint CF_DIB = 8;
    private const uint CF_DIBV5 = 17;

    /// <summary>The standard formats that hold plain memory, by id. The others are GDI handles or synthesized.</summary>
    private static readonly Dictionary<uint, string> StandardFormats = new()
    {
        [4] = "CF_SYLK",
        [5] = "CF_DIF",
        [6] = "CF_TIFF",
        [CF_DIB] = ClipboardFormats.Dib,
        [10] = "CF_PENDATA",
        [11] = "CF_RIFF",
        [12] = "CF_WAVE",
        [13] = ClipboardFormats.UnicodeText,
        [15] = ClipboardFormats.FileDrop,
        [CF_DIBV5] = ClipboardFormats.DibV5,
    };

    private static readonly Dictionary<string, uint> StandardFormatIds = StandardFormats.ToDictionary(f => f.Value, f => f.Key);

    private readonly MessageWindow owner;
    private readonly IAppLogger logger;

    public Win32Clipboard(MessageWindow owner, IAppLogger logger)
    {
        this.owner = owner;
        this.logger = logger;
    }

    public uint SequenceNumber => GetClipboardSequenceNumber();

    public ClipboardSnapshot? Read()
    {
        if (!TryOpen())
        {
            return null;
        }
        try
        {
            var formats = new List<KeyValuePair<string, byte[]>>();
            var hasDib = false;
            for (var format = EnumClipboardFormats(0); format != 0; format = EnumClipboardFormats(format))
            {
                // Windows lists the formats in the order the app added them, then the ones it can synthesize. Keep
                // whichever device-independent bitmap came first; Windows makes the other one from it.
                if (format is CF_DIB or CF_DIBV5)
                {
                    if (hasDib)
                    {
                        continue;
                    }
                    hasDib = true;
                }
                if (NameOf(format) is { } name && ReadMemory(GetClipboardData(format)) is { } data)
                {
                    formats.Add(KeyValuePair.Create(name, data));
                }
            }
            return new ClipboardSnapshot(new ClipboardContent(formats), SourceApp());
        }
        finally
        {
            CloseClipboard();
        }
    }

    public uint Write(ClipboardContent content)
    {
        if (!TryOpen())
        {
            logger.Warning("Couldn't open the clipboard to write to it; another app is holding it.");
            return SequenceNumber;
        }
        try
        {
            EmptyClipboard();
            foreach (var (name, data) in content.Formats)
            {
                var id = IdOf(name);
                if (id == 0)
                {
                    continue;
                }
                var memory = ToMemory(data);
                if (memory != IntPtr.Zero && SetClipboardData(id, memory) == IntPtr.Zero)
                {
                    // The clipboard only takes ownership when it succeeds
                    GlobalFree(memory);
                    logger.Warning($"Couldn't put the {name} format on the clipboard (error {Marshal.GetLastWin32Error()}).");
                }
            }
        }
        finally
        {
            CloseClipboard();
        }
        return SequenceNumber;
    }

    public uint Clear()
    {
        if (TryOpen())
        {
            EmptyClipboard();
            CloseClipboard();
        }
        return SequenceNumber;
    }

    /// <summary>Opens the clipboard, retrying for a moment if another app has it open.</summary>
    private bool TryOpen()
    {
        for (var attempt = 0; attempt < 10; attempt++)
        {
            if (OpenClipboard(owner.Handle))
            {
                return true;
            }
            Thread.Sleep(15);
        }
        return false;
    }

    /// <summary>The app that owns the clipboard, or the app in front if no window owns it.</summary>
    private static Domain.Apps.AppIdentity? SourceApp()
    {
        var window = GetClipboardOwner();
        if (window == IntPtr.Zero)
        {
            window = GetForegroundWindow();
        }
        return ProcessPaths.AppOfWindow(window);
    }

    private static string? NameOf(uint format)
    {
        if (StandardFormats.TryGetValue(format, out var standard))
        {
            return standard;
        }
        // Registered formats; anything below is a GDI handle, a private or a display format
        if (format < 0xC000)
        {
            return null;
        }
        var name = new StringBuilder(256);
        return GetClipboardFormatName(format, name, name.Capacity) > 0 ? name.ToString() : null;
    }

    private static uint IdOf(string name)
    {
        return StandardFormatIds.TryGetValue(name, out var id) ? id : RegisterClipboardFormat(name);
    }

    private static byte[]? ReadMemory(IntPtr memory)
    {
        if (memory == IntPtr.Zero)
        {
            return null;
        }
        var size = (long)GlobalSize(memory).ToUInt64();
        if (size == 0 || size > MaxFormatSize)
        {
            return size == 0 ? Array.Empty<byte>() : null;
        }
        var pointer = GlobalLock(memory);
        if (pointer == IntPtr.Zero)
        {
            return null;
        }
        try
        {
            var data = new byte[size];
            Marshal.Copy(pointer, data, 0, data.Length);
            return data;
        }
        finally
        {
            GlobalUnlock(memory);
        }
    }

    private static IntPtr ToMemory(byte[] data)
    {
        var memory = GlobalAlloc(GMEM_MOVEABLE, (UIntPtr)Math.Max(data.Length, 1));
        if (memory == IntPtr.Zero)
        {
            return IntPtr.Zero;
        }
        var pointer = GlobalLock(memory);
        if (pointer == IntPtr.Zero)
        {
            GlobalFree(memory);
            return IntPtr.Zero;
        }
        Marshal.Copy(data, 0, pointer, data.Length);
        GlobalUnlock(memory);
        return memory;
    }
}
