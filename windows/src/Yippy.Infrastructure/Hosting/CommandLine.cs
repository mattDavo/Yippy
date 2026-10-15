namespace Yippy.Infrastructure.Hosting;

/// <summary>What Yippy.exe was started to do.</summary>
public enum StartupAction
{
    /// <summary>Run in the notification area (no arguments).</summary>
    Run,

    /// <summary><c>--use-win-v</c>: make Win+V open Yippy, then exit.</summary>
    UseWinV,

    /// <summary><c>--restore-win-v</c>: give Win+V back to Windows' clipboard history, then exit.</summary>
    RestoreWinV,

    /// <summary><c>--quit</c>: close the running copy of Yippy, then exit.</summary>
    Quit,
}

/// <summary>
/// Yippy.exe's command line. The commands are what the installer and uninstaller run, and what
/// <c>scripts/*.ps1</c> do without Yippy; anything else starts Yippy as usual.
/// </summary>
/// <param name="RestartsShell">
/// Whether a Win+V change restarts Explorer straight away (leave it out with <c>--no-restart</c>; it then applies at the
/// next sign-in).
/// </param>
public sealed record CommandLine(StartupAction Action, bool RestartsShell)
{
    public const string UseWinVSwitch = "--use-win-v";
    public const string RestoreWinVSwitch = "--restore-win-v";
    public const string QuitSwitch = "--quit";
    public const string NoRestartSwitch = "--no-restart";

    /// <summary>Whether Yippy only carries out a command and exits, without opening anything.</summary>
    public bool IsCommand => Action != StartupAction.Run;

    public static CommandLine Parse(IEnumerable<string> args)
    {
        var action = StartupAction.Run;
        var restartsShell = true;
        foreach (var arg in args.Select(a => a.Trim().ToLowerInvariant()))
        {
            switch (arg)
            {
                case UseWinVSwitch or "/use-win-v":
                    action = StartupAction.UseWinV;
                    break;
                case RestoreWinVSwitch or "/restore-win-v":
                    action = StartupAction.RestoreWinV;
                    break;
                case QuitSwitch or "/quit":
                    action = StartupAction.Quit;
                    break;
                case NoRestartSwitch or "/no-restart":
                    restartsShell = false;
                    break;
            }
        }
        return new CommandLine(action, restartsShell);
    }
}
