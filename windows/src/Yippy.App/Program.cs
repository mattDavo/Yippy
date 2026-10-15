using Yippy.App.Shell;
using Yippy.Infrastructure.Hosting;

namespace Yippy.App;

/// <summary>
/// Yippy.exe's entry point. Runs a command-line command (for the installer) without starting WPF, or else starts the app.
/// </summary>
public static class Program
{
    [STAThread]
    public static int Main(string[] args)
    {
        var command = CommandLine.Parse(args);
        if (command.IsCommand)
        {
            using var instance = new SingleInstance(App.InstanceName);
            var runner = new CommandRunner(instance, () => CompositionRoot.Build(AppPaths.ForCurrentUser(App.InstanceName), () => { }));
            return (int)runner.Run(command);
        }

        var app = new App();
        app.InitializeComponent();
        return app.Run();
    }
}
