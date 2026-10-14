using System.Globalization;

namespace Yippy.Domain.History;

/// <summary>Short descriptions of how long ago something happened, like "5 min ago".</summary>
public static class TimeAgo
{
    public static string Format(DateTimeOffset date, DateTimeOffset now)
    {
        var elapsed = now - date;
        if (elapsed < TimeSpan.FromMinutes(1))
        {
            return "just now";
        }
        if (elapsed < TimeSpan.FromHours(1))
        {
            return $"{(int)elapsed.TotalMinutes} min ago";
        }
        if (elapsed < TimeSpan.FromDays(1))
        {
            return $"{(int)elapsed.TotalHours} hr ago";
        }
        if (elapsed < TimeSpan.FromDays(7))
        {
            var days = (int)elapsed.TotalDays;
            return days == 1 ? "yesterday" : $"{days} days ago";
        }
        return date.ToLocalTime().ToString("d MMM yyyy", CultureInfo.CurrentCulture);
    }
}
