using Yippy.Infrastructure.Hosting;
using Yippy.Platform.Windows.Apps;
using Yippy.UseCases.Abstractions;

namespace Yippy.App.Shell;

/// <summary>
/// Carries a copy of the app installed under its earlier name (<see cref="Brand.LegacyName"/>) over, the first time it runs:
/// closes the old copy, moves its data folder, and moves its launch at sign-in entry.
/// </summary>
public static class LegacyMigration
{
    private static readonly TimeSpan QuitTimeout = TimeSpan.FromSeconds(10);

    /// <param name="instanceName">This build's instance name (<see cref="App.InstanceName"/>).</param>
    /// <param name="legacyInstanceName">The same build's instance name before the rename.</param>
    public static void Run(string instanceName, string legacyInstanceName)
    {
        if (AppPaths.IsOverridden)
        {
            return;
        }
        var current = AppPaths.ForCurrentUser(instanceName);
        var legacyRoot = AppPaths.InAppData(legacyInstanceName);
        if (Directory.Exists(current.Root) || !Directory.Exists(legacyRoot))
        {
            return;
        }

        // The old copy saves its history when asked to quit; holding its mutex keeps it from starting again meanwhile
        using (var legacy = new SingleInstance(legacyInstanceName))
        {
            if (!legacy.RequestQuit(QuitTimeout))
            {
                return;
            }
            if (!LegacyDataFolder.MoveTo(current, legacyRoot))
            {
                return;
            }
        }

        var logger = NullLogger.Instance;
        var legacyStartup = new RegistryStartupRegistration(legacyInstanceName, logger);
        if (legacyStartup.IsEnabled)
        {
            legacyStartup.SetEnabled(false);
            new RegistryStartupRegistration(instanceName, logger).SetEnabled(true);
        }
    }

    private sealed class NullLogger : IAppLogger
    {
        public static readonly NullLogger Instance = new();

        public void Error(string message, Exception? exception = null)
        {
        }

        public void Warning(string message)
        {
        }
    }
}
