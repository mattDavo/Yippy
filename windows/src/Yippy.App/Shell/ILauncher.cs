using System.Diagnostics;

namespace Yippy.App.Shell;

/// <summary>Opens web pages and folders in the user's apps (their browser, File Explorer).</summary>
public interface ILauncher
{
    /// <param name="target">A URL or a folder path.</param>
    void Open(string target);
}

public sealed class ShellLauncher : ILauncher
{
    public void Open(string target)
    {
        Process.Start(new ProcessStartInfo(target) { UseShellExecute = true })?.Dispose();
    }
}
