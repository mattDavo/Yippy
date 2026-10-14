namespace Yippy.Infrastructure.Hosting;

/// <summary>Where Yippy keeps its files: <c>%APPDATA%\Yippy</c> unless <c>YIPPY_DATA_DIR</c> says otherwise.</summary>
public sealed record AppPaths(string Root)
{
    public const string DataDirectoryVariable = "YIPPY_DATA_DIR";

    public string History => Path.Combine(Root, "history");

    public string Favourites => Path.Combine(Root, "favourites");

    public string Settings => Path.Combine(Root, "settings.json");

    /// <param name="folderName">The folder under %APPDATA%, so development builds can keep their own history.</param>
    public static AppPaths ForCurrentUser(string folderName)
    {
        var overridden = Environment.GetEnvironmentVariable(DataDirectoryVariable);
        var root = string.IsNullOrWhiteSpace(overridden)
            ? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), folderName)
            : overridden;
        return new AppPaths(root);
    }
}
