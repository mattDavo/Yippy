using System.Diagnostics;
using System.Runtime.InteropServices;
using Yippy.UseCases.Abstractions;
using static Yippy.Platform.Windows.Native.NativeMethods;

namespace Yippy.Platform.Windows.Input;

/// <summary>
/// Pastes by giving the previous app its focus back and pressing Ctrl+V in it with <c>SendInput</c>.
/// </summary>
/// <remarks>
/// Windows doesn't let a normal app send keys to an app running as administrator, so pasting into one only puts the item
/// on the clipboard.
/// </remarks>
public sealed class SendInputPasteSimulator : IPasteSimulator
{
    private static readonly TimeSpan FocusTimeout = TimeSpan.FromSeconds(2);
    private static readonly TimeSpan PollInterval = TimeSpan.FromMilliseconds(20);

    /// <summary>
    /// How long to wait after the app is in front before pressing Ctrl+V. Apps such as Windows 11 Notepad give their editor
    /// focus a moment after their window comes to the front, and drop keys that arrive before that.
    /// </summary>
    private static readonly TimeSpan SettleDelay = TimeSpan.FromMilliseconds(100);

    private readonly ForegroundWindowTracker tracker;
    private readonly IAppLogger logger;

    public SendInputPasteSimulator(ForegroundWindowTracker tracker, IAppLogger logger)
    {
        this.tracker = tracker;
        this.logger = logger;
    }

    public async Task PasteAsync()
    {
        var target = tracker.LastExternalWindow;
        if (target == IntPtr.Zero)
        {
            return;
        }
        tracker.ActivateLastExternalWindow();

        var waited = Stopwatch.StartNew();
        // Wait for the app to come to the front, and for Shift, Alt and Win from Yippy's own shortcuts to be let go,
        // so they don't turn Ctrl+V into another shortcut (Ctrl+Shift+V would even reopen the panel)
        while (waited.Elapsed < FocusTimeout
            && (GetForegroundWindow() != target || !HasKeyboardFocus(target) || IsAnyHeld(VK_SHIFT, VK_MENU, VK_LWIN, VK_RWIN)))
        {
            await Task.Delay(PollInterval);
        }
        if (GetForegroundWindow() != target)
        {
            // Pasting into whatever else is in front would be a surprise; the item is on the clipboard either way
            logger.Warning("The previous app didn't come back to the front, so the item was copied but not pasted.");
            return;
        }
        await Task.Delay(SettleDelay);
        if (GetForegroundWindow() != target)
        {
            logger.Warning("The previous app lost the focus again, so the item was copied but not pasted.");
            return;
        }
        PressCtrlV();
    }

    /// <summary>Whether one of the window's controls has the keyboard focus, so it receives the keys.</summary>
    private static bool HasKeyboardFocus(IntPtr window)
    {
        var thread = GetWindowThreadProcessId(window, out _);
        var info = new GUITHREADINFO { Size = Marshal.SizeOf<GUITHREADINFO>() };
        // If the app can't be asked (e.g. it runs as administrator), don't hold the paste up
        return !GetGUIThreadInfo(thread, ref info) || info.Focus != IntPtr.Zero;
    }

    private static bool IsAnyHeld(params ushort[] keys) => keys.Any(IsHeld);

    private static bool IsHeld(ushort key) => (GetAsyncKeyState(key) & 0x8000) != 0;

    private static void PressCtrlV()
    {
        // Ctrl may still be down from Ctrl+1…9; then it is left as the user holds it
        var ctrlHeld = IsHeld(VK_CONTROL);
        var inputs = new List<INPUT>();
        if (!ctrlHeld)
        {
            inputs.Add(Key(VK_CONTROL, false));
        }
        inputs.Add(Key(VK_V, false));
        inputs.Add(Key(VK_V, true));
        if (!ctrlHeld)
        {
            inputs.Add(Key(VK_CONTROL, true));
        }
        SendInput((uint)inputs.Count, inputs.ToArray(), Marshal.SizeOf<INPUT>());
    }

    private static INPUT Key(ushort virtualKey, bool up) => new()
    {
        Type = INPUT_KEYBOARD,
        Data = new InputUnion
        {
            Keyboard = new KEYBDINPUT
            {
                VirtualKey = virtualKey,
                Flags = up ? KEYEVENTF_KEYUP : 0,
            },
        },
    };
}
