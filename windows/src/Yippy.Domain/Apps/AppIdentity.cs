namespace Yippy.Domain.Apps;

/// <summary>
/// An app, identified by its executable's file name (e.g. <c>notepad.exe</c>), the Windows counterpart of a macOS bundle id.
/// </summary>
/// <param name="Id">The executable's file name. Compared without case.</param>
/// <param name="Path">The full path of the executable when known, for its name and icon.</param>
public sealed record AppIdentity(string Id, string? Path = null)
{
    public static AppIdentity FromPath(string path)
    {
        // Windows paths, whichever OS this runs on (the tests run on Linux too)
        var name = path[(path.LastIndexOfAny(new[] { '\\', '/' }) + 1)..];
        return new AppIdentity(name, path);
    }

    public bool Matches(string id) => string.Equals(Id, id, StringComparison.OrdinalIgnoreCase);

    /// <summary>The executable's name without ".exe", for when its real name can't be looked up.</summary>
    public string GetFallbackName() => Id.EndsWith(".exe", StringComparison.OrdinalIgnoreCase) ? Id[..^4] : Id;

    public bool Equals(AppIdentity? other) => other is not null && Matches(other.Id);

    public override int GetHashCode() => StringComparer.OrdinalIgnoreCase.GetHashCode(Id);
}
