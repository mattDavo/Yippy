namespace Yippy.Infrastructure.Hosting;

/// <summary>Where the app keeps its files: <c>%APPDATA%\Cairn</c> unless <c>CAIRN_DATA_DIR</c> says otherwise.</summary>
public sealed record AppPaths(string Root)
{
    public const string DataDirectoryVariable = "CAIRN_DATA_DIR";

    public string History => Path.Combine(Root, "history");

    public string Favourites => Path.Combine(Root, "favourites");

    public string Settings => Path.Combine(Root, "settings.json");

    public string SyncState => Path.Combine(Root, "sync.json");

    /// <summary>The sync key, encrypted for the current Windows user.</summary>
    public string SyncKey => Path.Combine(Root, "sync-key.bin");

    /// <summary>Whether <see cref="DataDirectoryVariable"/> chose the folder, rather than the user's profile.</summary>
    public static bool IsOverridden => !string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable(DataDirectoryVariable));

    /// <param name="folderName">The folder under %APPDATA%, so development builds can keep their own history.</param>
    public static AppPaths ForCurrentUser(string folderName) =>
        new(IsOverridden ? Environment.GetEnvironmentVariable(DataDirectoryVariable)! : InAppData(folderName));

    /// <summary>The folder under %APPDATA% with this name, whether or not it exists.</summary>
    public static string InAppData(string folderName) =>
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), folderName);
}
