using System.Windows.Interop;

namespace Yippy.Platform.Windows.Native;

/// <summary>
/// A hidden message-only window that receives clipboard and hot key notifications and owns what Yippy puts on the clipboard.
/// Create it on the UI thread.
/// </summary>
public sealed class MessageWindow : IDisposable
{
    private const int HwndMessage = -3;

    private readonly HwndSource source;
    private readonly Dictionary<int, Action<IntPtr, IntPtr>> handlers = new();

    public MessageWindow()
    {
        source = new HwndSource(new HwndSourceParameters("Yippy")
        {
            ParentWindow = new IntPtr(HwndMessage),
            WindowStyle = 0,
        });
        source.AddHook(WndProc);
    }

    public IntPtr Handle => source.Handle;

    /// <summary>Calls <paramref name="handler"/> with wParam and lParam whenever the window gets the message.</summary>
    public void On(int message, Action<IntPtr, IntPtr> handler)
    {
        handlers[message] = handler;
    }

    public void Dispose()
    {
        source.RemoveHook(WndProc);
        source.Dispose();
    }

    private IntPtr WndProc(IntPtr hwnd, int message, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (handlers.TryGetValue(message, out var handler))
        {
            handler(wParam, lParam);
            handled = true;
        }
        return IntPtr.Zero;
    }
}
