using Yippy.Domain.Apps;
using Yippy.Domain.Clipboard;
using Yippy.Domain.Settings;
using Yippy.Domain.Text;
using Yippy.Domain.Transforms;
using Yippy.Tests.Fakes;

namespace Yippy.Tests.UseCases;

public class ClipboardCaptureServiceTests
{
    private static readonly AppIdentity Notepad = AppIdentity.FromPath(@"C:\Windows\notepad.exe");

    [Fact]
    public void AddsEachCopyWithItsSourceAndTime()
    {
        var app = new TestApp();

        app.Clipboard.Copy("first", Notepad);
        app.Clipboard.Copy("second");

        Assert.Equal(new[] { "second", "first" }, app.Texts);
        Assert.Equal(Notepad, app.History.Items[1].Metadata.Source);
        Assert.Equal(app.Clock.Now, app.History.Items[1].Metadata.CopiedAt);
        Assert.Equal(app.Clipboard.SequenceNumber, app.Settings.Current.ClipboardSequenceNumber);
    }

    [Fact]
    public void ACopyAlreadyInTheHistoryMovesToTheTop()
    {
        var app = new TestApp();
        app.Clipboard.Copy("a");
        app.Clipboard.Copy("b");
        app.Clock.Advance(TimeSpan.FromMinutes(5));

        app.Clipboard.Copy("a", Notepad);

        Assert.Equal(new[] { "a", "b" }, app.Texts);
        Assert.Equal(app.Clock.Now, app.History.Items[0].Metadata.CopiedAt);
        Assert.Equal(Notepad, app.History.Items[0].Metadata.Source);
    }

    [Fact]
    public void SkipsIgnoredAppsButRecordsTheChange()
    {
        var app = new TestApp(AppSettings.Default with { IgnoredApps = new[] { new AppIdentity("NOTEPAD.EXE") } });

        app.Clipboard.Copy("secret", Notepad);
        app.Capture.Capture();

        Assert.Empty(app.History.Items);
        Assert.True(app.Capture.IsClipboardUnchanged);
    }

    [Fact]
    public void SkipsCopiesMarkedForClipboardManagersToIgnore()
    {
        var app = new TestApp();

        app.Clipboard.Copy(new ClipboardContent(new[]
        {
            KeyValuePair.Create(ClipboardFormats.UnicodeText, UnicodeText.Encode("password")),
            KeyValuePair.Create(ClipboardFormats.CanIncludeInClipboardHistory, BitConverter.GetBytes(0u)),
        }));

        Assert.Empty(app.History.Items);
    }

    [Fact]
    public void IgnoresItsOwnChangesAndTheSameChangeTwice()
    {
        var app = new TestApp();
        app.Clipboard.Copy("a");

        app.Capture.RecordOwnChange(app.Clipboard.Write(ClipboardContent.FromText("mine")));
        app.Capture.Capture();
        app.Capture.Capture();

        Assert.Equal(new[] { "a" }, app.Texts);
    }

    [Fact]
    public void ALockedClipboardIsRetriedOnTheNextChange()
    {
        var app = new TestApp();
        app.Clipboard.IsLocked = true;
        app.Clipboard.Copy("a");
        Assert.Empty(app.History.Items);

        app.Clipboard.IsLocked = false;
        app.Capture.Capture();

        Assert.Equal(new[] { "a" }, app.Texts);
    }
}

public class PasteServiceTests
{
    [Fact]
    public async Task PastingMovesTheItemToTheTopWithoutAddingIt()
    {
        var app = new TestApp();
        app.Clipboard.Copy("a");
        app.Clipboard.Copy("b");

        await app.Paste.PasteAsync(app.History, app.History.Items[1]);
        app.Capture.Capture();

        Assert.Equal(new[] { "a", "b" }, app.Texts);
        Assert.Equal("a", UnicodeText.Decode(app.Clipboard.Content.Get(ClipboardFormats.UnicodeText)!));
        Assert.Equal(1, app.Simulator.Pastes);
    }

    [Fact]
    public async Task PastingAFavouriteKeepsItsOrderAndAddsItToTheClipboardHistory()
    {
        var app = new TestApp();
        app.Clipboard.Copy("a");
        app.Editing.ToggleFavourite(app.History.Items[0]);
        app.Clipboard.Copy("b");
        app.Editing.ToggleFavourite(app.History.Items[0]);

        await app.Paste.PasteAsync(app.Favourites, app.Favourites.Items[1]);
        app.Capture.Capture();

        Assert.Equal(new[] { "b", "a" }, app.Favourites.Items.Select(i => i.PlainText));
        Assert.Equal(new[] { "a", "b" }, app.Texts);
    }

    [Fact]
    public async Task PlainTextLeavesTheStylingOut()
    {
        var app = new TestApp();
        app.Clipboard.Copy(RichText("Hello"));

        await app.Paste.PastePlainTextAsync(app.History, app.History.Items[0]);

        Assert.Equal(new[] { ClipboardFormats.UnicodeText }, app.Clipboard.Content.FormatNames);
    }

    [Fact]
    public async Task RichTextIsLeftOutWhenTurnedOff()
    {
        var app = new TestApp(AppSettings.Default with { PastesRichText = false });
        app.Clipboard.Copy(RichText("Hello"));

        await app.Paste.PasteAsync(app.History, app.History.Items[0]);

        Assert.Equal(new[] { ClipboardFormats.UnicodeText }, app.Clipboard.Content.FormatNames);
    }

    [Fact]
    public async Task TransformsThatDoNotApplyPasteNothing()
    {
        var app = new TestApp();
        app.Clipboard.Copy("  not json ");

        await app.Paste.PasteTransformedAsync(app.History, app.History.Items[0], new PrettyPrintJson());
        Assert.Equal(0, app.Simulator.Pastes);

        await app.Paste.PasteTransformedAsync(app.History, app.History.Items[0], new TrimWhitespace());
        Assert.Equal("not json", UnicodeText.Decode(app.Clipboard.Content.Get(ClipboardFormats.UnicodeText)!));
        Assert.Equal(1, app.Simulator.Pastes);
    }

    private static ClipboardContent RichText(string text) => new(new[]
    {
        KeyValuePair.Create(ClipboardFormats.UnicodeText, UnicodeText.Encode(text)),
        KeyValuePair.Create(ClipboardFormats.Rtf, System.Text.Encoding.ASCII.GetBytes(@"{\rtf1 \b " + text + "}")),
    });
}

public class HistoryEditingServiceTests
{
    [Fact]
    public void FavouritesKeepTheirOwnCopy()
    {
        var app = new TestApp();
        app.Clipboard.Copy("a");

        Assert.True(app.Editing.ToggleFavourite(app.History.Items[0]));
        app.History.Clear();

        Assert.Equal("a", app.Favourites.Items[0].PlainText);
    }

    [Fact]
    public void TogglingAgainRemovesTheFavourite()
    {
        var app = new TestApp();
        app.Clipboard.Copy("a");
        var item = app.History.Items[0];
        app.Editing.ToggleFavourite(item);

        Assert.True(app.Editing.IsFavourite(item));
        Assert.False(app.Editing.ToggleFavourite(item));
        Assert.False(app.Editing.IsFavourite(item));
        Assert.Empty(app.Favourites.Items);
    }

    [Fact]
    public void DeletingTheTopItemClearsItFromTheClipboard()
    {
        var app = new TestApp();
        app.Clipboard.Copy("a");
        app.Clipboard.Copy("b");

        app.Editing.Delete(app.History, app.History.Items[1]);
        Assert.False(app.Clipboard.Content.IsEmpty);

        app.Editing.Delete(app.History, app.History.Items[0]);
        Assert.True(app.Clipboard.Content.IsEmpty);
        Assert.Empty(app.History.Items);
    }

    [Fact]
    public void DeletingTheTopFavouriteLeavesTheClipboardAlone()
    {
        var app = new TestApp();
        app.Clipboard.Copy("a");
        app.Editing.ToggleFavourite(app.History.Items[0]);

        app.Editing.Delete(app.Favourites, app.Favourites.Items[0]);

        Assert.False(app.Clipboard.Content.IsEmpty);
    }

    [Fact]
    public void MovingAnItemToTheTopPutsItOnTheClipboard()
    {
        var app = new TestApp();
        app.Clipboard.Copy("a");
        app.Clipboard.Copy("b");

        app.Editing.Move(app.History, app.History.Items[1], 0);
        app.Capture.Capture();

        Assert.Equal(new[] { "a", "b" }, app.Texts);
        Assert.Equal("a", UnicodeText.Decode(app.Clipboard.Content.Get(ClipboardFormats.UnicodeText)!));
    }

    [Fact]
    public void RenamesAndEditsFavourites()
    {
        var app = new TestApp();
        app.Clipboard.Copy("old text");
        app.Editing.ToggleFavourite(app.History.Items[0]);

        app.Editing.Rename(app.Favourites.Items[0], "  Address ");
        app.Editing.EditText(app.Favourites.Items[0], "new text");

        Assert.Equal("Address", app.Favourites.Items[0].Metadata.Title);
        Assert.Equal("new text", app.Favourites.Items[0].PlainText);

        app.Editing.Rename(app.Favourites.Items[0], " ");
        Assert.Null(app.Favourites.Items[0].Metadata.Title);
    }
}
