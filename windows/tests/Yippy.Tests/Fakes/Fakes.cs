using Yippy.Domain.Apps;
using Yippy.Domain.Clipboard;
using Yippy.Domain.Settings;
using Yippy.UseCases.Abstractions;

namespace Yippy.Tests.Fakes;

/// <summary>A clipboard in memory. <see cref="Copy"/> plays another app copying something.</summary>
public sealed class FakeClipboard : IClipboard, IClipboardMonitor
{
    public event EventHandler? ClipboardChanged;

    public uint SequenceNumber { get; private set; } = 1;

    public ClipboardContent Content { get; private set; } = ClipboardContent.Empty;

    public AppIdentity? Owner { get; private set; }

    public bool IsLocked { get; set; }

    public int Writes { get; private set; }

    public ClipboardSnapshot? Read() => IsLocked ? null : new ClipboardSnapshot(Content, Owner);

    public uint Write(ClipboardContent content)
    {
        Writes++;
        Set(content, null);
        return SequenceNumber;
    }

    public uint Clear()
    {
        Set(ClipboardContent.Empty, null);
        return SequenceNumber;
    }

    /// <summary>Another app copies <paramref name="content"/>, and the change is announced.</summary>
    public void Copy(ClipboardContent content, AppIdentity? owner = null)
    {
        Set(content, owner);
        ClipboardChanged?.Invoke(this, EventArgs.Empty);
    }

    public void Copy(string text, AppIdentity? owner = null) => Copy(ClipboardContent.FromText(text), owner);

    private void Set(ClipboardContent content, AppIdentity? owner)
    {
        Content = content;
        Owner = owner;
        SequenceNumber++;
    }
}

public sealed class FakeClock : IClock
{
    public DateTimeOffset Now { get; set; } = new(2026, 10, 14, 12, 0, 0, TimeSpan.Zero);

    public void Advance(TimeSpan by) => Now += by;
}

public sealed class InMemorySettingsRepository : ISettingsRepository
{
    public InMemorySettingsRepository(AppSettings? saved = null)
    {
        Saved = saved;
    }

    public AppSettings? Saved { get; private set; }

    public int Saves { get; private set; }

    public AppSettings? Load() => Saved;

    public void Save(AppSettings settings)
    {
        Saved = settings;
        Saves++;
    }
}

public sealed class FakePasteSimulator : IPasteSimulator
{
    public int Pastes { get; private set; }

    public Task PasteAsync()
    {
        Pastes++;
        return Task.CompletedTask;
    }
}

public sealed class FakeTextRecognizer : ITextRecognizer
{
    public bool IsAvailable { get; set; } = true;

    public Func<byte[], string?> Recognize { get; set; } = _ => "recognised";

    public int Reads { get; private set; }

    public Task<string?> RecognizeAsync(byte[] image, CancellationToken cancellationToken)
    {
        Reads++;
        return Task.FromResult(Recognize(image));
    }
}

public sealed class FakeAppInfo : IAppInfoProvider
{
    public Dictionary<string, string> Names { get; } = new(StringComparer.OrdinalIgnoreCase);

    public string GetDisplayName(AppIdentity app) => Names.TryGetValue(app.Id, out var name) ? name : app.GetFallbackName();

    public IReadOnlyList<AppIdentity> GetRunningApps() => Array.Empty<AppIdentity>();
}

public sealed class FakeGlobalHotKeys : IGlobalHotKeys
{
    public HashSet<HotKeyGesture> TakenByOtherApps { get; } = new();

    public Dictionary<HotKeyGesture, Action> Registered { get; } = new();

    public IDisposable? TryRegister(HotKeyGesture gesture, Action onPressed)
    {
        if (TakenByOtherApps.Contains(gesture) || Registered.ContainsKey(gesture))
        {
            return null;
        }
        Registered[gesture] = onPressed;
        return new Registration(() => Registered.Remove(gesture));
    }

    public void Press(HotKeyGesture gesture) => Registered[gesture]();

    private sealed class Registration(Action dispose) : IDisposable
    {
        public void Dispose() => dispose();
    }
}

public sealed class RecordingLogger : IAppLogger
{
    public List<string> Errors { get; } = new();

    public List<string> Warnings { get; } = new();

    public void Error(string message, Exception? exception = null) => Errors.Add(message);

    public void Warning(string message) => Warnings.Add(message);
}
