using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using Yippy.Domain.Settings;

namespace Yippy.App.Presentation;

/// <summary>
/// A box that records a keyboard shortcut: click it and press the keys. Raises <see cref="GestureTyped"/> with them.
/// </summary>
public sealed class HotKeyBox : TextBox
{
    public HotKeyBox()
    {
        IsReadOnly = true;
        IsReadOnlyCaretVisible = false;
        Cursor = Cursors.Hand;
        InputMethod.SetIsInputMethodEnabled(this, false);
    }

    public event EventHandler? RecordingStarted;

    public event EventHandler? RecordingEnded;

    public event EventHandler<HotKeyGesture>? GestureTyped;

    protected override void OnGotKeyboardFocus(KeyboardFocusChangedEventArgs e)
    {
        base.OnGotKeyboardFocus(e);
        RecordingStarted?.Invoke(this, EventArgs.Empty);
    }

    protected override void OnLostKeyboardFocus(KeyboardFocusChangedEventArgs e)
    {
        base.OnLostKeyboardFocus(e);
        RecordingEnded?.Invoke(this, EventArgs.Empty);
    }

    protected override void OnPreviewKeyDown(KeyEventArgs e)
    {
        e.Handled = true;
        var key = e.Key switch
        {
            Key.System => e.SystemKey,
            Key.ImeProcessed => e.ImeProcessedKey,
            _ => e.Key,
        };
        if (IsModifier(key))
        {
            return;
        }
        var modifiers = ToModifiers(Keyboard.Modifiers);
        if (key == Key.Escape && modifiers == KeyModifiers.None)
        {
            StopRecording();
            return;
        }
        if (key is Key.Tab && modifiers is KeyModifiers.None or KeyModifiers.Shift)
        {
            // Let Tab move on to the next control
            e.Handled = false;
            return;
        }
        GestureTyped?.Invoke(this, new HotKeyGesture(KeyInterop.VirtualKeyFromKey(key), modifiers));
        StopRecording();
    }

    private void StopRecording()
    {
        // Moving focus to the window ends recording, which registers the shortcut again
        var scope = FocusManager.GetFocusScope(this);
        FocusManager.SetFocusedElement(scope, null);
        Keyboard.ClearFocus();
    }

    private static bool IsModifier(Key key) => key is Key.LeftCtrl or Key.RightCtrl or Key.LeftAlt or Key.RightAlt
        or Key.LeftShift or Key.RightShift or Key.LWin or Key.RWin;

    private static KeyModifiers ToModifiers(ModifierKeys keys)
    {
        var modifiers = KeyModifiers.None;
        if (keys.HasFlag(ModifierKeys.Control))
        {
            modifiers |= KeyModifiers.Control;
        }
        if (keys.HasFlag(ModifierKeys.Alt))
        {
            modifiers |= KeyModifiers.Alt;
        }
        if (keys.HasFlag(ModifierKeys.Shift))
        {
            modifiers |= KeyModifiers.Shift;
        }
        if (keys.HasFlag(ModifierKeys.Windows))
        {
            modifiers |= KeyModifiers.Windows;
        }
        return modifiers;
    }
}
