using System.Text;
using Yippy.Domain.Apps;
using static Yippy.Platform.Windows.Native.NativeMethods;

namespace Yippy.Platform.Windows.Apps;

/// <summary>Finds the executable behind a process or window.</summary>
public static class ProcessPaths
{
    /// <returns>The full path of the process's executable, or null if it can't be read (e.g. an elevated process).</returns>
    public static string? Of(uint processId)
    {
        var process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, false, processId);
        if (process == IntPtr.Zero)
        {
            return null;
        }
        try
        {
            var size = 1024u;
            var path = new StringBuilder((int)size);
            return QueryFullProcessImageName(process, 0, path, ref size) ? path.ToString() : null;
        }
        finally
        {
            CloseHandle(process);
        }
    }

    /// <returns>The app that owns the window, or null for Yippy's own windows and when it can't be found.</returns>
    public static AppIdentity? AppOfWindow(IntPtr hwnd)
    {
        if (hwnd == IntPtr.Zero)
        {
            return null;
        }
        GetWindowThreadProcessId(hwnd, out var processId);
        if (processId == 0 || processId == Environment.ProcessId)
        {
            return null;
        }
        return Of(processId) is { } path ? AppIdentity.FromPath(path) : null;
    }
}
