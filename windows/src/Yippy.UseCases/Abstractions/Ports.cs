using Yippy.Domain.Apps;
using Yippy.Domain.Clipboard;
using Yippy.Domain.History;
using Yippy.Domain.Settings;

namespace Yippy.UseCases.Abstractions;

// Ports: what the use cases need from the outside world. Infrastructure and the Windows platform layer implement them,
// and the tests replace them with fakes.

/// <summary>What was on the clipboard, and which app put it there.</summary>
public sealed record ClipboardSnapshot(ClipboardContent Content, AppIdentity? Source);

/// <summary>The system clipboard.</summary>
public interface IClipboard
{
    /// <summary>Changes every time the clipboard's content changes (Win32 <c>GetClipboardSequenceNumber</c>).</summary>
    uint SequenceNumber { get; }

    /// <returns>Every format on the clipboard, or null if it couldn't be opened (another app is holding it).</returns>
    ClipboardSnapshot? Read();

    /// <summary>Replaces the clipboard's content.</summary>
    /// <returns>The sequence number after writing, so the change can be recognised as Yippy's own.</returns>
    uint Write(ClipboardContent content);

    /// <returns>The sequence number after clearing.</returns>
    uint Clear();
}

/// <summary>Announces clipboard changes. Raised on the UI thread.</summary>
public interface IClipboardMonitor
{
    event EventHandler? ClipboardChanged;
}

/// <summary>A history item as it is stored.</summary>
public sealed record StoredItem(Guid Id, IReadOnlyList<string> Formats, string ContentHash, ItemMetadata Metadata);

/// <summary>
/// Stores one history's items (Repository pattern). Writes may happen in the background, but reads always see them.
/// </summary>
public interface IHistoryRepository : IItemDataSource
{
    /// <returns>The stored items, in history order.</returns>
    IReadOnlyList<StoredItem> Load();

    void Add(Guid id, ClipboardContent content);

    void Delete(Guid id);

    void DeleteAll();

    /// <summary>Saves the order, hashes and metadata of the items. Called after every change, so it may put the write off.</summary>
    void SaveIndex(IReadOnlyList<StoredItem> items);

    /// <summary>Completes once every change so far is on disk.</summary>
    Task FlushAsync();
}

public interface ISettingsRepository
{
    /// <returns>The saved settings, or null if there are none yet (the first launch).</returns>
    AppSettings? Load();

    void Save(AppSettings settings);
}

public interface IClock
{
    DateTimeOffset Now { get; }
}

/// <summary>Pastes into the app that was in front before Yippy's panel opened.</summary>
public interface IPasteSimulator
{
    /// <summary>Gives the previous app its focus back and presses Ctrl+V in it.</summary>
    Task PasteAsync();
}

/// <summary>Reads the text in images (OCR).</summary>
public interface ITextRecognizer
{
    bool IsAvailable { get; }

    /// <param name="image">A PNG or BMP file.</param>
    /// <returns>The text found, "" if there is none, or null if the image couldn't be read.</returns>
    Task<string?> RecognizeAsync(byte[] image, CancellationToken cancellationToken);
}

/// <summary>Whether Yippy starts when the user logs in.</summary>
public interface IStartupRegistration
{
    bool IsEnabled { get; }

    void SetEnabled(bool enabled);
}

public interface IAppLogger
{
    void Error(string message, Exception? exception = null);

    void Warning(string message);
}

public interface IAppInfoProvider
{
    /// <summary>The app's display name, or its executable name if it can't be found. Cached.</summary>
    string GetDisplayName(AppIdentity app);

    /// <summary>Apps that have a window open, for picking apps in the settings.</summary>
    IReadOnlyList<AppIdentity> GetRunningApps();
}

/// <summary>System-wide keyboard shortcuts.</summary>
public interface IGlobalHotKeys
{
    /// <returns>A registration to dispose to unregister it, or null if another app already uses the shortcut.</returns>
    IDisposable? TryRegister(HotKeyGesture gesture, Action onPressed);
}

/// <summary>
/// Windows' own Win+V shortcut, which opens its clipboard history. Explorer registers it, so no other app can until
/// Explorer is told to leave it alone.
/// </summary>
public interface IShellClipboardShortcut
{
    /// <summary>Whether Explorer has been told to leave Win+V alone.</summary>
    bool IsReleased { get; }

    /// <summary>Tells Explorer to leave Win+V alone. Takes effect when Explorer restarts.</summary>
    void Release();

    /// <summary>Gives Win+V back to Explorer. Takes effect when Explorer restarts.</summary>
    void Restore();

    /// <summary>Restarts Explorer (the taskbar and desktop) so a change takes effect.</summary>
    Task RestartShellAsync();
}

/// <summary>
/// The PowerShell scripts that hand Win+V to Yippy or back to Windows without Yippy running, e.g. for an administrator
/// setting up another account. They ship inside Cairn.exe.
/// </summary>
public interface IClipboardShortcutScripts
{
    IReadOnlyList<string> FileNames { get; }

    /// <summary>Writes the scripts into a folder, replacing older copies.</summary>
    /// <returns>The files written.</returns>
    IReadOnlyList<string> SaveTo(string folder);
}
