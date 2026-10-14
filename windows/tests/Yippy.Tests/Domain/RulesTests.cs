using Yippy.Domain.Apps;
using Yippy.Domain.History;
using Yippy.Domain.Settings;
using Yippy.Domain.Transforms;

namespace Yippy.Tests.Domain;

public class TextTransformTests
{
    [Fact]
    public void CaseAndWhitespace()
    {
        Assert.Equal("hi there", new TrimWhitespace().Apply("  hi there \n"));
        Assert.Equal("HELLO", new Uppercase().Apply("Hello"));
        Assert.Equal("hello", new Lowercase().Apply("HeLLo"));
        Assert.Equal("Hello World", new TitleCase().Apply("hELLO wORLD"));
    }

    [Fact]
    public void RemovesTrackingParametersAndKeepsTheRest()
    {
        var transform = new RemoveLinkTracking();

        Assert.Equal(
            "See https://example.com/a?id=5&q=x%20y#top and https://x.org/",
            transform.Apply("See https://example.com/a?utm_source=news&id=5&fbclid=abc&q=x%20y#top and https://x.org/?gclid=1"));
    }

    [Fact]
    public void LinksWithoutTrackingAreUnchanged()
    {
        Assert.Null(RemoveLinkTracking.RemoveTrackingParameters("https://example.com/a?id=5"));
        Assert.Null(RemoveLinkTracking.RemoveTrackingParameters("https://example.com/a"));
    }

    [Fact]
    public void PrettyPrintsJsonWithSortedKeys()
    {
        var pretty = new PrettyPrintJson().Apply("{\"b\":1,\"a\":{\"d\":\"x/y\",\"c\":[1,2]}}");

        Assert.Equal("{\n  \"a\": {\n    \"c\": [\n      1,\n      2\n    ],\n    \"d\": \"x/y\"\n  },\n  \"b\": 1\n}", pretty!.ReplaceLineEndings("\n"));
    }

    [Theory]
    [InlineData("not json")]
    [InlineData("42")]
    [InlineData("\"a string\"")]
    public void PrettyPrintOnlyAppliesToObjectsAndArrays(string text)
    {
        Assert.Null(new PrettyPrintJson().Apply(text));
    }

    [Fact]
    public void EveryTransformIsListedOnce()
    {
        Assert.Equal(6, TextTransforms.All.Select(t => t.Title).Distinct().Count());
    }
}

public class AutoCleanPolicyTests
{
    private static readonly DateTimeOffset Now = new(2026, 10, 14, 12, 0, 0, TimeSpan.Zero);
    private static readonly AppIdentity Terminal = new("WindowsTerminal.exe");

    [Fact]
    public void InactiveByDefault()
    {
        Assert.False(AppSettings.Default.GetAutoCleanPolicy().IsActive);
    }

    [Fact]
    public void ExpiresByAge()
    {
        var policy = new AutoCleanPolicy(7, Array.Empty<AppIdentity>());

        Assert.True(policy.IsExpired(new ItemMetadata { CopiedAt = Now.AddDays(-7) }, Now));
        Assert.False(policy.IsExpired(new ItemMetadata { CopiedAt = Now.AddDays(-6) }, Now));
        Assert.False(policy.IsExpired(ItemMetadata.None, Now));
    }

    [Fact]
    public void ExpiresItemsFromExpiringAppsAfterAMinute()
    {
        var policy = new AutoCleanPolicy(0, new[] { Terminal });
        var fromTerminal = new ItemMetadata { Source = new AppIdentity("windowsterminal.EXE"), CopiedAt = Now.AddSeconds(-60) };
        var fresh = fromTerminal with { CopiedAt = Now.AddSeconds(-59) };
        var fromElsewhere = fromTerminal with { Source = new AppIdentity("notepad.exe") };

        Assert.True(policy.IsExpired(fromTerminal, Now));
        Assert.False(policy.IsExpired(fresh, Now));
        Assert.False(policy.IsExpired(fromElsewhere, Now));
    }
}

public class PanelLayoutTests
{
    private static readonly ScreenRect WorkArea = new(1920, 0, 1920, 1040);

    [Fact]
    public void EdgesUseTheScaledSize()
    {
        Assert.Equal(new ScreenRect(1920 + 1920 - 600, 0, 600, 1040), PanelLayout.GetFrame(PanelPosition.Right, WorkArea, 1.5));
        Assert.Equal(new ScreenRect(1920, 0, 400, 1040), PanelLayout.GetFrame(PanelPosition.Left, WorkArea, 1));
        Assert.Equal(new ScreenRect(1920, 0, 1920, 300), PanelLayout.GetFrame(PanelPosition.Top, WorkArea, 1));
        Assert.Equal(new ScreenRect(1920, 740, 1920, 300), PanelLayout.GetFrame(PanelPosition.Bottom, WorkArea, 1));
    }

    [Fact]
    public void CentersAreCentered()
    {
        Assert.Equal(new ScreenRect(1920 + 480, 260, 960, 520), PanelLayout.GetFrame(PanelPosition.CenterSmall, WorkArea, 1));
        Assert.Equal(WorkArea, PanelLayout.GetFrame(PanelPosition.FullScreen, WorkArea, 2));
    }

    [Fact]
    public void ThePreviewSitsBesideEdgePanelsAndInsideOthers()
    {
        var right = PanelLayout.GetFrame(PanelPosition.Right, WorkArea, 1);
        var top = PanelLayout.GetFrame(PanelPosition.Top, WorkArea, 1);
        var center = PanelLayout.GetFrame(PanelPosition.CenterSmall, WorkArea, 1);

        Assert.Equal(new ScreenRect(right.X - 560, 0, 560, 1040), PanelLayout.GetPreviewFrame(PanelPosition.Right, right, WorkArea, 1));
        Assert.Equal(new ScreenRect(1920 + 680, 300, 560, 450), PanelLayout.GetPreviewFrame(PanelPosition.Top, top, WorkArea, 1));
        Assert.Equal(new ScreenRect(center.Right - 480, center.Y, 480, center.Height), PanelLayout.GetPreviewFrame(PanelPosition.CenterSmall, center, WorkArea, 1));
    }

    [Fact]
    public void NeverLargerThanTheScreen()
    {
        var small = new ScreenRect(0, 0, 300, 200);

        Assert.Equal(small, PanelLayout.GetFrame(PanelPosition.Right, small, 2) with { X = 0 });
    }
}

public class HotKeyGestureTests
{
    [Fact]
    public void DefaultIsCtrlShiftV()
    {
        Assert.Equal("Ctrl+Shift+V", HotKeyGesture.DefaultToggle.ToString());
    }

    [Fact]
    public void NeedsAModifierUnlessItIsAFunctionKey()
    {
        Assert.False(new HotKeyGesture('V', KeyModifiers.None).IsValid);
        Assert.True(new HotKeyGesture(0x7B, KeyModifiers.None).IsValid);
        Assert.Equal("Alt+Win+F12", new HotKeyGesture(0x7B, KeyModifiers.Windows | KeyModifiers.Alt).ToString());
    }
}

public class TimeAgoTests
{
    private static readonly DateTimeOffset Now = new(2026, 10, 14, 12, 0, 0, TimeSpan.Zero);

    [Theory]
    [InlineData(30, "just now")]
    [InlineData(5 * 60, "5 min ago")]
    [InlineData(3 * 3600, "3 hr ago")]
    [InlineData(30 * 3600, "yesterday")]
    [InlineData(3 * 86400, "3 days ago")]
    public void DescribesRecentTimes(int secondsAgo, string expected)
    {
        Assert.Equal(expected, TimeAgo.Format(Now.AddSeconds(-secondsAgo), Now));
    }
}
