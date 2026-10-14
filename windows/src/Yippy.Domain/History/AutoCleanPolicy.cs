using Yippy.Domain.Apps;

namespace Yippy.Domain.History;

/// <summary>
/// Decides which clipboard history items have expired, for the History settings' automatic deletion. Favourites are never cleaned.
/// </summary>
/// <param name="MaxAgeDays">Items older than this many days are deleted. 0 keeps them forever.</param>
/// <param name="ExpiringApps">Items copied from these apps are deleted once they are <see cref="ExpiringItemLifetime"/> old.</param>
public sealed record AutoCleanPolicy(int MaxAgeDays, IReadOnlyCollection<AppIdentity> ExpiringApps)
{
    /// <summary>How long items copied from one of the <see cref="ExpiringApps"/> are kept.</summary>
    public static readonly TimeSpan ExpiringItemLifetime = TimeSpan.FromMinutes(1);

    /// <summary>The choices offered for <see cref="MaxAgeDays"/>, in menu order.</summary>
    public static IReadOnlyList<(string Title, int Days)> MaxAgeDaysOptions { get; } = new[]
    {
        ("Never", 0),
        ("After 1 day", 1),
        ("After 1 week", 7),
        ("After 1 month", 30),
        ("After 3 months", 90),
    };

    /// <summary>Whether anything can expire at all.</summary>
    public bool IsActive => MaxAgeDays > 0 || ExpiringApps.Count > 0;

    /// <summary>Whether an item with this metadata should be deleted at <paramref name="now"/>. Items with no copy date never expire.</summary>
    public bool IsExpired(ItemMetadata metadata, DateTimeOffset now)
    {
        if (metadata.CopiedAt is not { } copiedAt)
        {
            return false;
        }
        var age = now - copiedAt;
        if (MaxAgeDays > 0 && age >= TimeSpan.FromDays(MaxAgeDays))
        {
            return true;
        }
        return metadata.Source is { } source && ExpiringApps.Contains(source) && age >= ExpiringItemLifetime;
    }
}
