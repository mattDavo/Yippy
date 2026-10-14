using Yippy.Platform.Windows.Native;
using Yippy.UseCases.Abstractions;
using static Yippy.Platform.Windows.Native.NativeMethods;

namespace Yippy.Platform.Windows.Clipboard;

/// <summary>Raises <see cref="ClipboardChanged"/> whenever any app changes the clipboard (<c>WM_CLIPBOARDUPDATE</c>).</summary>
public sealed class ClipboardMonitor : IClipboardMonitor, IDisposable
{
    private readonly MessageWindow window;

    public ClipboardMonitor(MessageWindow window)
    {
        this.window = window;
        window.On(WM_CLIPBOARDUPDATE, (_, _) => ClipboardChanged?.Invoke(this, EventArgs.Empty));
        if (!AddClipboardFormatListener(window.Handle))
        {
            throw new InvalidOperationException("Couldn't listen for clipboard changes.");
        }
    }

    public event EventHandler? ClipboardChanged;

    public void Dispose() => RemoveClipboardFormatListener(window.Handle);
}
