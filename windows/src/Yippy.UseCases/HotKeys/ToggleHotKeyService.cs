using Yippy.Domain.Settings;
using Yippy.UseCases.Abstractions;
using Yippy.UseCases.Settings;

namespace Yippy.UseCases.HotKeys;

/// <summary>Keeps the system-wide shortcut that opens and closes the panel registered, and lets the user change it.</summary>
public sealed class ToggleHotKeyService : IDisposable
{
    private readonly IGlobalHotKeys hotKeys;
    private readonly SettingsService settings;
    private Action onPressed = () => { };
    private IDisposable? registration;

    public ToggleHotKeyService(IGlobalHotKeys hotKeys, SettingsService settings)
    {
        this.hotKeys = hotKeys;
        this.settings = settings;
    }

    public HotKeyGesture Current => settings.Current.ToggleHotKey;

    public bool IsRegistered => registration is not null;

    /// <summary>Registers the saved shortcut.</summary>
    /// <returns>False if another app already uses it.</returns>
    public bool Start(Action onPressed)
    {
        this.onPressed = onPressed;
        registration = hotKeys.TryRegister(Current, () => this.onPressed());
        return registration is not null;
    }

    /// <summary>Switches to a new shortcut and saves it, unless another app already uses it (then the old one stays).</summary>
    public bool TryChange(HotKeyGesture gesture)
    {
        if (!gesture.IsValid)
        {
            return false;
        }
        registration?.Dispose();
        var updated = hotKeys.TryRegister(gesture, () => onPressed());
        if (updated is null)
        {
            registration = hotKeys.TryRegister(Current, () => onPressed());
            return false;
        }
        registration = updated;
        settings.Update(s => s with { ToggleHotKey = gesture });
        return true;
    }

    /// <summary>Lets the shortcut through to other apps for a while, e.g. while a new one is being typed in the settings.</summary>
    public void Suspend()
    {
        registration?.Dispose();
        registration = null;
    }

    public void Resume()
    {
        registration ??= hotKeys.TryRegister(Current, () => onPressed());
    }

    public void Dispose()
    {
        registration?.Dispose();
        registration = null;
    }
}
