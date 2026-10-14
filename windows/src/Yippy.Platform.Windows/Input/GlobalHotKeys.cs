using Yippy.Domain.Settings;
using Yippy.Platform.Windows.Native;
using Yippy.UseCases.Abstractions;
using static Yippy.Platform.Windows.Native.NativeMethods;

namespace Yippy.Platform.Windows.Input;

/// <summary>System-wide shortcuts through <c>RegisterHotKey</c>. Use from the UI thread.</summary>
public sealed class GlobalHotKeys : IGlobalHotKeys
{
    private readonly MessageWindow window;
    private readonly Dictionary<int, Action> handlers = new();
    private int nextId;

    public GlobalHotKeys(MessageWindow window)
    {
        this.window = window;
        window.On(WM_HOTKEY, (wParam, _) =>
        {
            if (handlers.TryGetValue(wParam.ToInt32(), out var handler))
            {
                handler();
            }
        });
    }

    public IDisposable? TryRegister(HotKeyGesture gesture, Action onPressed)
    {
        var id = ++nextId;
        // KeyModifiers has the same values as the MOD_ flags
        if (!RegisterHotKey(window.Handle, id, (uint)gesture.Modifiers | MOD_NOREPEAT, (uint)gesture.VirtualKey))
        {
            return null;
        }
        handlers[id] = onPressed;
        return new Registration(this, id);
    }

    private sealed class Registration : IDisposable
    {
        private readonly GlobalHotKeys owner;
        private readonly int id;
        private bool isDisposed;

        public Registration(GlobalHotKeys owner, int id)
        {
            this.owner = owner;
            this.id = id;
        }

        public void Dispose()
        {
            if (isDisposed)
            {
                return;
            }
            isDisposed = true;
            UnregisterHotKey(owner.window.Handle, id);
            owner.handlers.Remove(id);
        }
    }
}
