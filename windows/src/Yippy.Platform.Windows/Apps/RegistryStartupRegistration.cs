using System.IO;
using Microsoft.Win32;
using Yippy.UseCases.Abstractions;

namespace Yippy.Platform.Windows.Apps;

/// <summary>Launch at login through the current user's <c>Run</c> registry key.</summary>
public sealed class RegistryStartupRegistration : IStartupRegistration
{
    private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";

    private readonly string valueName;
    private readonly IAppLogger logger;

    /// <param name="valueName">The name of the entry, so development builds don't replace the installed app's.</param>
    public RegistryStartupRegistration(string valueName, IAppLogger logger)
    {
        this.valueName = valueName;
        this.logger = logger;
    }

    public bool IsEnabled
    {
        get
        {
            using var key = Registry.CurrentUser.OpenSubKey(RunKey);
            return key?.GetValue(valueName) is string;
        }
    }

    public void SetEnabled(bool enabled)
    {
        try
        {
            using var key = Registry.CurrentUser.CreateSubKey(RunKey);
            if (enabled)
            {
                key.SetValue(valueName, $"\"{Environment.ProcessPath}\"");
            }
            else
            {
                key.DeleteValue(valueName, throwOnMissingValue: false);
            }
        }
        catch (Exception e) when (e is UnauthorizedAccessException or System.Security.SecurityException or IOException)
        {
            logger.Error("Couldn't change launch at login.", e);
        }
    }
}
