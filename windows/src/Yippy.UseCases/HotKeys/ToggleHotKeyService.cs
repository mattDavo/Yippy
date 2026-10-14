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
    private bool isSuspended;

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
        registration = hotKeys.TryRegister(Current, Pressed);
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
        registration = null;
        var updated = hotKeys.TryRegister(gesture, Pressed);
        if (updated is null)
        {
            if (!isSuspended)
            {
                registration = hotKeys.TryRegister(Current, Pressed);
            }
            return false;
        }
        settings.Update(s => s with { ToggleHotKey = gesture });
        if (isSuspended)
        {
            // It was only registered to check it's free; Resume registers it for good
            updated.Dispose();
        }
        else
        {
            registration = updated;
        }
        return true;
    }

    /// <summary>Lets the shortcut through to other apps for a while, e.g. while a new one is being typed in the settings.</summary>
    public void Suspend()
    {
        isSuspended = true;
        registration?.Dispose();
        registration = null;
    }

    public void Resume()
    {
        isSuspended = false;
        registration ??= hotKeys.TryRegister(Current, Pressed);
    }

    private void Pressed() => onPressed();

    public void Dispose()
    {
        registration?.Dispose();
        registration = null;
    }
}
