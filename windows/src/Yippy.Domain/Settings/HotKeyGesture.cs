namespace Yippy.Domain.Settings;

[Flags]
public enum KeyModifiers
{
    None = 0,
    Alt = 1,
    Control = 2,
    Shift = 4,
    Windows = 8,
}

/// <summary>A system-wide keyboard shortcut: a Win32 virtual-key code and modifiers.</summary>
public readonly record struct HotKeyGesture(int VirtualKey, KeyModifiers Modifiers)
{
    private const int VkF1 = 0x70;
    private const int VkF24 = 0x87;

    /// <summary>Ctrl+Shift+V, the counterpart of the macOS app's ⌘⇧V.</summary>
    public static HotKeyGesture DefaultToggle { get; } = new('V', KeyModifiers.Control | KeyModifiers.Shift);

    /// <summary>Win+V, which opens Windows' own clipboard history unless Yippy takes it over.</summary>
    public static HotKeyGesture WindowsClipboard { get; } = new('V', KeyModifiers.Windows);

    /// <summary>
    /// Whether the gesture can be a system-wide shortcut: it needs a modifier, so typing isn't taken away from every app,
    /// unless the key is a function key.
    /// </summary>
    public bool IsValid => VirtualKey > 0 && (Modifiers != KeyModifiers.None || (VirtualKey >= VkF1 && VirtualKey <= VkF24));

    public override string ToString()
    {
        var parts = new List<string>();
        if (Modifiers.HasFlag(KeyModifiers.Control))
        {
            parts.Add("Ctrl");
        }
        if (Modifiers.HasFlag(KeyModifiers.Alt))
        {
            parts.Add("Alt");
        }
        if (Modifiers.HasFlag(KeyModifiers.Shift))
        {
            parts.Add("Shift");
        }
        if (Modifiers.HasFlag(KeyModifiers.Windows))
        {
            parts.Add("Win");
        }
        parts.Add(KeyName(VirtualKey));
        return string.Join('+', parts);
    }

    /// <summary>A readable name for a virtual-key code.</summary>
    public static string KeyName(int virtualKey) => virtualKey switch
    {
        >= '0' and <= '9' or >= 'A' and <= 'Z' => ((char)virtualKey).ToString(),
        >= VkF1 and <= VkF24 => $"F{virtualKey - VkF1 + 1}",
        >= 0x60 and <= 0x69 => $"Num {virtualKey - 0x60}",
        0x08 => "Backspace",
        0x09 => "Tab",
        0x0D => "Enter",
        0x1B => "Esc",
        0x20 => "Space",
        0x21 => "Page Up",
        0x22 => "Page Down",
        0x23 => "End",
        0x24 => "Home",
        0x25 => "Left",
        0x26 => "Up",
        0x27 => "Right",
        0x28 => "Down",
        0x2D => "Insert",
        0x2E => "Delete",
        0xBA => ";",
        0xBB => "=",
        0xBC => ",",
        0xBD => "-",
        0xBE => ".",
        0xBF => "/",
        0xC0 => "`",
        0xDB => "[",
        0xDC => "\\",
        0xDD => "]",
        0xDE => "'",
        _ => $"Key {virtualKey}",
    };
}
