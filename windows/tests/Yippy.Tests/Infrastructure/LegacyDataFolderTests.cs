using Yippy.Infrastructure.Hosting;

namespace Yippy.Tests.Infrastructure;

public sealed class LegacyDataFolderTests : IDisposable
{
    private readonly string root = Path.Combine(Path.GetTempPath(), "cairn-tests-" + Guid.NewGuid().ToString("N"));

    public void Dispose()
    {
        if (Directory.Exists(root))
        {
            Directory.Delete(root, recursive: true);
        }
    }

    [Fact]
    public void MovesTheOldFolderWithItsFiles()
    {
        var legacy = Path.Combine(root, "Yippy");
        Directory.CreateDirectory(Path.Combine(legacy, "history"));
        File.WriteAllText(Path.Combine(legacy, "settings.json"), "{}");
        var current = new AppPaths(Path.Combine(root, "Cairn"));

        Assert.True(LegacyDataFolder.MoveTo(current, legacy));

        Assert.False(Directory.Exists(legacy));
        Assert.True(File.Exists(current.Settings));
        Assert.True(Directory.Exists(current.History));
    }

    [Fact]
    public void LeavesAnExistingFolderAlone()
    {
        var legacy = Path.Combine(root, "Yippy");
        Directory.CreateDirectory(legacy);
        File.WriteAllText(Path.Combine(legacy, "settings.json"), "old");
        var current = new AppPaths(Path.Combine(root, "Cairn"));
        Directory.CreateDirectory(current.Root);
        File.WriteAllText(current.Settings, "new");

        Assert.False(LegacyDataFolder.MoveTo(current, legacy));

        Assert.Equal("new", File.ReadAllText(current.Settings));
        Assert.True(Directory.Exists(legacy));
    }

    [Fact]
    public void DoesNothingWithoutAnOldFolder()
    {
        var current = new AppPaths(Path.Combine(root, "Cairn"));

        Assert.False(LegacyDataFolder.MoveTo(current, Path.Combine(root, "Yippy")));

        Assert.False(Directory.Exists(current.Root));
    }
}
