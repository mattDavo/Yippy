namespace Yippy.App;

/// <summary>The product's name and links, in one place for the app, the tray and the installer's commands.</summary>
/// <remarks>Cairn started as a Windows port of Yippy by Matthew Davidson; the code keeps Yippy as its internal name.</remarks>
public static class Brand
{
    public const string Name = "Cairn";

    /// <summary>The name this app had before, whose data folder and sign-in entry are moved over once.</summary>
    public const string LegacyName = "Yippy";

    public const string Repository = "https://github.com/Hamza-Shewa/Yippy";

    public const string Credit =
        "Cairn is based on Yippy by Matthew Davidson, and is open source under the MIT License.";
}
