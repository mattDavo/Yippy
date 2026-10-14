using System.Diagnostics;
using System.IO;
using Yippy.Domain.Apps;
using Yippy.UseCases.Abstractions;

namespace Yippy.Platform.Windows.Apps;

/// <summary>App names from the executables' version information, and the apps that have a window open.</summary>
public sealed class WindowsAppInfoProvider : IAppInfoProvider
{
    private readonly Dictionary<string, string> names = new(StringComparer.OrdinalIgnoreCase);

    public string GetDisplayName(AppIdentity app)
    {
        if (names.TryGetValue(app.Id, out var cached))
        {
            return cached;
        }
        var name = DescriptionOf(app.Path) ?? app.GetFallbackName();
        // Only remember real names, so an app seen first without a path gets its name once one is known
        if (app.Path is not null)
        {
            names[app.Id] = name;
        }
        return name;
    }

    public IReadOnlyList<AppIdentity> GetRunningApps()
    {
        var apps = new Dictionary<string, AppIdentity>(StringComparer.OrdinalIgnoreCase);
        foreach (var process in Process.GetProcesses())
        {
            using (process)
            {
                if (process.Id == Environment.ProcessId || process.MainWindowHandle == IntPtr.Zero)
                {
                    continue;
                }
                if (ProcessPaths.Of((uint)process.Id) is { } path)
                {
                    var app = AppIdentity.FromPath(path);
                    apps.TryAdd(app.Id, app);
                }
            }
        }
        return apps.Values.OrderBy(GetDisplayName, StringComparer.CurrentCultureIgnoreCase).ToList();
    }

    private static string? DescriptionOf(string? path)
    {
        if (path is null || !File.Exists(path))
        {
            return null;
        }
        try
        {
            var info = FileVersionInfo.GetVersionInfo(path);
            return new[] { info.FileDescription, info.ProductName }.FirstOrDefault(n => !string.IsNullOrWhiteSpace(n))?.Trim();
        }
        catch (FileNotFoundException)
        {
            return null;
        }
    }
}
