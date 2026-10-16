namespace Yippy.Infrastructure.Hosting;

/// <summary>Moves the history, favourites and settings an earlier name of the app kept to the current folder, once.</summary>
public static class LegacyDataFolder
{
    /// <summary>
    /// Moves <paramref name="legacyRoot"/> to <paramref name="current"/>'s root, unless the current folder already exists
    /// (the move happened, or the app already ran under its new name) or there is nothing to move.
    /// </summary>
    /// <returns>Whether the folder was moved. A failed move (e.g. a file still in use) leaves both folders as they were.</returns>
    public static bool MoveTo(AppPaths current, string legacyRoot)
    {
        if (Directory.Exists(current.Root) || !Directory.Exists(legacyRoot))
        {
            return false;
        }
        try
        {
            var parent = Path.GetDirectoryName(Path.GetFullPath(current.Root));
            if (parent is not null)
            {
                Directory.CreateDirectory(parent);
            }
            Directory.Move(legacyRoot, current.Root);
            return true;
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException)
        {
            return false;
        }
    }
}
