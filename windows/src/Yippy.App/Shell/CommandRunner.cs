using System.Diagnostics;
using Microsoft.Extensions.DependencyInjection;
using Yippy.Infrastructure.Hosting;
using Yippy.UseCases.Abstractions;
using Yippy.UseCases.HotKeys;

namespace Yippy.App.Shell;

/// <summary>Cairn.exe's exit codes when it runs a command.</summary>
public enum CommandExitCode
{
    Success = 0,
    Failed = 1,

    /// <summary>The running copy of Yippy didn't quit when asked.</summary>
    StillRunning = 2,
}

/// <summary>
/// Carries out a command from Cairn.exe's command line (<see cref="CommandLine"/>) without starting the WPF app, for the
/// installer and uninstaller. A running copy of Yippy is closed first, so it can't overwrite the change with its own
/// settings, and started again afterwards.
/// </summary>
public sealed class CommandRunner
{
    private static readonly TimeSpan QuitTimeout = TimeSpan.FromSeconds(10);

    private readonly SingleInstance instance;
    private readonly Func<IServiceProvider> buildServices;

    /// <param name="buildServices">Makes the services; only called when a command needs them.</param>
    public CommandRunner(SingleInstance instance, Func<IServiceProvider> buildServices)
    {
        this.instance = instance;
        this.buildServices = buildServices;
    }

    /// <summary>Call it on the thread that made the <see cref="SingleInstance"/>, which owns its mutex.</summary>
    public CommandExitCode Run(CommandLine command)
    {
        var wasRunning = !instance.IsFirst;
        if (wasRunning && !instance.RequestQuit(QuitTimeout))
        {
            return CommandExitCode.StillRunning;
        }
        if (command.Action == StartupAction.Quit)
        {
            return CommandExitCode.Success;
        }

        var services = buildServices();
        try
        {
            var setup = services.GetRequiredService<WindowsClipboardShortcutSetup>();
            // Wait here rather than await, so this thread (which holds the mutex) carries on afterwards
            var change = command.Action == StartupAction.UseWinV
                ? setup.UseWinVAsync(command.RestartsShell)
                : setup.RestoreAsync(command.RestartsShell);
            change.GetAwaiter().GetResult();
        }
        catch (Exception e)
        {
            services.GetRequiredService<IAppLogger>().Error($"Couldn't carry out {command.Action}.", e);
            return CommandExitCode.Failed;
        }
        finally
        {
            (services as IDisposable)?.Dispose();
        }

        if (wasRunning)
        {
            // Start Yippy again, now with the new shortcut; it needs the mutex this copy holds
            instance.Dispose();
            Process.Start(new ProcessStartInfo(Environment.ProcessPath!) { UseShellExecute = false })?.Dispose();
        }
        return CommandExitCode.Success;
    }
}
