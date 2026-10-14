using Yippy.Domain.Settings;
using Yippy.UseCases.Abstractions;

namespace Yippy.UseCases.Settings;

public sealed class SettingsChangedEventArgs : EventArgs
{
    public SettingsChangedEventArgs(AppSettings old, AppSettings current)
    {
        Old = old;
        Current = current;
    }

    public AppSettings Old { get; }

    public AppSettings Current { get; }
}

/// <summary>Holds the current settings, saves every change and tells subscribers about it.</summary>
public sealed class SettingsService
{
    private readonly ISettingsRepository repository;

    public SettingsService(ISettingsRepository repository)
    {
        this.repository = repository;
        var saved = repository.Load();
        IsFirstLaunch = saved is null;
        Current = saved ?? AppSettings.Default;
    }

    public event EventHandler<SettingsChangedEventArgs>? Changed;

    public AppSettings Current { get; private set; }

    /// <summary>Whether there were no saved settings when Yippy started.</summary>
    public bool IsFirstLaunch { get; }

    public void Update(Func<AppSettings, AppSettings> change)
    {
        var old = Current;
        var updated = change(old);
        if (updated == old)
        {
            return;
        }
        Current = updated;
        repository.Save(updated);
        Changed?.Invoke(this, new SettingsChangedEventArgs(old, updated));
    }
}
