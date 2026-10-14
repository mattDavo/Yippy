using System.Diagnostics;
using Microsoft.Win32;
using Yippy.UseCases.Abstractions;
using static Yippy.Platform.Windows.Native.NativeMethods;

namespace Yippy.Platform.Windows.Input;

/// <summary>
/// Frees Win+V from Explorer through its <c>DisabledHotkeys</c> setting: each letter in it is a Win+letter shortcut
/// Explorer doesn't register when it starts. Only "V" is added or removed; other letters the user set are kept.
/// </summary>
/// <remarks><c>scripts/Use-YippyForWinV.ps1</c> and <c>scripts/Restore-WindowsWinV.ps1</c> make the same change.</remarks>
public sealed class ExplorerClipboardShortcut : IShellClipboardShortcut
{
    private const string AdvancedKey = @"Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced";
    private const string DisabledHotkeys = "DisabledHotkeys";
    private const char Letter = 'V';
    private static readonly TimeSpan ExitTimeout = TimeSpan.FromSeconds(5);
    private static readonly TimeSpan StartTimeout = TimeSpan.FromSeconds(10);
    private static readonly TimeSpan PollInterval = TimeSpan.FromMilliseconds(250);

    private readonly IAppLogger logger;

    public ExplorerClipboardShortcut(IAppLogger logger)
    {
        this.logger = logger;
    }

    public bool IsReleased => Read().Contains(Letter, StringComparison.OrdinalIgnoreCase);

    public void Release()
    {
        var letters = Read();
        if (!letters.Contains(Letter, StringComparison.OrdinalIgnoreCase))
        {
            Write(letters + Letter);
        }
    }

    public void Restore() => Write(new string(Read().Where(c => char.ToUpperInvariant(c) != Letter).ToArray()));

    /// <summary>Ends Explorer in this session and waits until the taskbar is back.</summary>
    public async Task RestartShellAsync()
    {
        var session = Process.GetCurrentProcess().SessionId;
        foreach (var explorer in ExplorersIn(session))
        {
            using (explorer)
            {
                try
                {
                    explorer.Kill();
                    using var timeout = new CancellationTokenSource(ExitTimeout);
                    await explorer.WaitForExitAsync(timeout.Token);
                }
                catch (Exception e) when (e is InvalidOperationException or System.ComponentModel.Win32Exception or OperationCanceledException)
                {
                    logger.Warning($"Couldn't end Explorer (process {explorer.Id}): {e.Message}");
                }
            }
        }

        // Windows normally starts the shell again by itself; start it if it hasn't after a moment
        var waited = Stopwatch.StartNew();
        var started = false;
        while (FindWindow("Shell_TrayWnd", null) == IntPtr.Zero && waited.Elapsed < StartTimeout)
        {
            if (!started && waited.Elapsed > TimeSpan.FromSeconds(2) && !IsRunning(session))
            {
                Process.Start(new ProcessStartInfo("explorer.exe") { UseShellExecute = true })?.Dispose();
                started = true;
            }
            await Task.Delay(PollInterval);
        }
    }

    /// <returns>Explorer's processes in the session; the caller disposes them.</returns>
    private static List<Process> ExplorersIn(int session)
    {
        var all = Process.GetProcessesByName("explorer");
        foreach (var other in all.Where(p => p.SessionId != session))
        {
            other.Dispose();
        }
        return all.Where(p => p.SessionId == session).ToList();
    }

    private static bool IsRunning(int session)
    {
        var explorers = ExplorersIn(session);
        explorers.ForEach(p => p.Dispose());
        return explorers.Count > 0;
    }

    private static string Read()
    {
        using var key = Registry.CurrentUser.OpenSubKey(AdvancedKey);
        return key?.GetValue(DisabledHotkeys) as string ?? string.Empty;
    }

    private static void Write(string letters)
    {
        using var key = Registry.CurrentUser.CreateSubKey(AdvancedKey);
        if (letters.Length == 0)
        {
            key.DeleteValue(DisabledHotkeys, throwOnMissingValue: false);
        }
        else
        {
            key.SetValue(DisabledHotkeys, letters, RegistryValueKind.String);
        }
    }
}
