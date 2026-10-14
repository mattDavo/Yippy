using Yippy.Infrastructure.Hosting;

namespace Yippy.Tests.Infrastructure;

public class CommandLineTests
{
    [Fact]
    public void NoArgumentsRunsYippy()
    {
        var command = CommandLine.Parse(Array.Empty<string>());

        Assert.Equal(StartupAction.Run, command.Action);
        Assert.False(command.IsCommand);
    }

    [Theory]
    [InlineData("--use-win-v", StartupAction.UseWinV)]
    [InlineData("/use-win-v", StartupAction.UseWinV)]
    [InlineData("--RESTORE-WIN-V", StartupAction.RestoreWinV)]
    [InlineData("--quit", StartupAction.Quit)]
    public void ReadsTheCommand(string arg, StartupAction expected)
    {
        var command = CommandLine.Parse(new[] { arg });

        Assert.Equal(expected, command.Action);
        Assert.True(command.IsCommand);
        Assert.True(command.RestartsShell);
    }

    [Fact]
    public void NoRestartLeavesExplorerRunning()
    {
        Assert.False(CommandLine.Parse(new[] { "--no-restart", "--use-win-v" }).RestartsShell);
    }

    [Fact]
    public void UnknownArgumentsAreIgnored()
    {
        Assert.Equal(StartupAction.Run, CommandLine.Parse(new[] { "--minimized", "C:\\file.txt" }).Action);
    }
}
