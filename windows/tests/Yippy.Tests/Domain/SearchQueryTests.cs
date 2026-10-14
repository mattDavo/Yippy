using Yippy.Domain.Clipboard;
using Yippy.Domain.Search;

namespace Yippy.Tests.Domain;

public class SearchQueryTests
{
    [Fact]
    public void SplitsFiltersFromWords()
    {
        var query = SearchQuery.Parse("hello /img @Code world /LINK");

        Assert.Equal("hello world", query.Text);
        Assert.Equal(new HashSet<ItemKind> { ItemKind.Image, ItemKind.Link }, query.Kinds);
        Assert.Equal(new[] { "code" }, query.Apps);
    }

    [Fact]
    public void UnknownFiltersAndLoneSymbolsAreWords()
    {
        var query = SearchQuery.Parse("/nope / @");

        Assert.Equal("/nope / @", query.Text);
        Assert.Empty(query.Kinds);
        Assert.Empty(query.Apps);
    }

    [Fact]
    public void AppFiltersMatchNameOrIdIgnoringSpacesAndCase()
    {
        var query = SearchQuery.Parse("@visualstudio");

        Assert.True(query.MatchesApp("Visual Studio Code", "Code.exe"));
        Assert.False(query.MatchesApp("Notepad", "notepad.exe"));
        Assert.True(SearchQuery.Parse("@notepad").MatchesApp(null, "notepad.exe"));
    }

    [Fact]
    public void AppFilterForANameDropsSpaces()
    {
        Assert.Equal("@VisualStudioCode", SearchQuery.AppFilter("Visual Studio Code"));
    }

    [Theory]
    [InlineData("hlo", "Hello", true)]
    [InlineData("HEL", "hello", true)]
    [InlineData("olh", "hello", false)]
    [InlineData("", "anything", true)]
    [InlineData("a", "", false)]
    public void FuzzyMatchIsAnInOrderSubsequence(string needle, string haystack, bool matches)
    {
        Assert.Equal(matches, FuzzyMatch.Matches(needle, haystack));
    }
}

public class ItemKindTests
{
    private static readonly string[] Text = { ClipboardFormats.UnicodeText };

    [Theory]
    [InlineData("https://example.com/a?b=c", ItemKind.Link)]
    [InlineData("  http://example.com  ", ItemKind.Link)]
    [InlineData("mailto:someone@example.com", ItemKind.Link)]
    [InlineData("see https://example.com", ItemKind.Text)]
    [InlineData("C:\\Windows", ItemKind.Text)]
    [InlineData("#ff8800", ItemKind.Color)]
    [InlineData("just words", ItemKind.Text)]
    public void TextKinds(string text, ItemKind kind)
    {
        Assert.Equal(kind, ItemKinds.Of(Text, text));
    }

    [Fact]
    public void FormatsDecideBeforeText()
    {
        Assert.Equal(ItemKind.File, ItemKinds.Of(new[] { ClipboardFormats.FileDrop, ClipboardFormats.UnicodeText }, "https://x.com"));
        Assert.Equal(ItemKind.Image, ItemKinds.Of(new[] { ClipboardFormats.Dib }, null));
        Assert.Equal(ItemKind.Link, ItemKinds.Of(new[] { ClipboardFormats.Url, ClipboardFormats.UnicodeText }, "a title"));
    }
}
