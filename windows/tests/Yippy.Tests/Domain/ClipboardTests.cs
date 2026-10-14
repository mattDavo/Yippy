using System.Text;
using Yippy.Domain.Clipboard;
using Yippy.Domain.Text;

namespace Yippy.Tests.Domain;

public class ClipboardContentTests
{
    [Fact]
    public void HashIgnoresTheOrderOfFormats()
    {
        var a = new ClipboardContent(new[] { KeyValuePair.Create("A", new byte[] { 1 }), KeyValuePair.Create("B", new byte[] { 2 }) });
        var b = new ClipboardContent(new[] { KeyValuePair.Create("B", new byte[] { 2 }), KeyValuePair.Create("A", new byte[] { 1 }) });

        Assert.Equal(a.Hash, b.Hash);
    }

    [Fact]
    public void HashDiffersWhenBytesOrFormatNamesDiffer()
    {
        var a = new ClipboardContent(new[] { KeyValuePair.Create("A", new byte[] { 1, 2 }) });
        var differentBytes = new ClipboardContent(new[] { KeyValuePair.Create("A", new byte[] { 1, 3 }) });
        var differentName = new ClipboardContent(new[] { KeyValuePair.Create("B", new byte[] { 1, 2 }) });
        // The same bytes split differently between the name and the data
        var shifted = new ClipboardContent(new[] { KeyValuePair.Create("A\u0001", new byte[] { 2 }) });

        Assert.NotEqual(a.Hash, differentBytes.Hash);
        Assert.NotEqual(a.Hash, differentName.Hash);
        Assert.NotEqual(a.Hash, shifted.Hash);
    }

    [Fact]
    public void FromTextHoldsNullTerminatedUnicodeText()
    {
        var content = ClipboardContent.FromText("hé");

        Assert.Equal(new[] { ClipboardFormats.UnicodeText }, content.FormatNames);
        Assert.Equal(Encoding.Unicode.GetBytes("hé\0"), content.Get(ClipboardFormats.UnicodeText));
    }

    [Fact]
    public void OptedOutWhenAMarkerFormatIsPresent()
    {
        var content = new ClipboardContent(new[]
        {
            KeyValuePair.Create(ClipboardFormats.UnicodeText, UnicodeText.Encode("hunter2")),
            KeyValuePair.Create("ExcludeClipboardContentFromMonitorProcessing", Array.Empty<byte>()),
        });

        Assert.True(ClipboardFormats.IsOptedOut(content));
    }

    [Fact]
    public void OptedOutOnlyWhenCanIncludeInClipboardHistoryIsZero()
    {
        ClipboardContent With(uint value) => new(new[]
        {
            KeyValuePair.Create(ClipboardFormats.UnicodeText, UnicodeText.Encode("x")),
            KeyValuePair.Create(ClipboardFormats.CanIncludeInClipboardHistory, BitConverter.GetBytes(value)),
        });

        Assert.True(ClipboardFormats.IsOptedOut(With(0)));
        Assert.False(ClipboardFormats.IsOptedOut(With(1)));
        Assert.False(ClipboardFormats.IsOptedOut(ClipboardContent.FromText("x")));
    }

    [Fact]
    public void PolicyFormatsAreNotKept()
    {
        var content = new ClipboardContent(new[]
        {
            KeyValuePair.Create(ClipboardFormats.UnicodeText, UnicodeText.Encode("x")),
            KeyValuePair.Create(ClipboardFormats.CanIncludeInClipboardHistory, BitConverter.GetBytes(1u)),
            KeyValuePair.Create("CanUploadToCloudClipboard", BitConverter.GetBytes(1u)),
        });

        Assert.Equal(new[] { ClipboardFormats.UnicodeText }, ClipboardFormats.WithoutPolicyFormats(content).FormatNames);
    }
}

public class TextFormatTests
{
    [Fact]
    public void UnicodeTextStopsAtTheNullTerminator()
    {
        var data = Encoding.Unicode.GetBytes("hello\0garbage");

        Assert.Equal("hello", UnicodeText.Decode(data));
        Assert.Equal("hello", UnicodeText.Decode(UnicodeText.Encode("hello")));
    }

    [Fact]
    public void RtfKeepsTheBodyText()
    {
        const string rtf = @"{\rtf1\ansi\ansicpg1252\deff0{\fonttbl{\f0\fnil Calibri;}}{\colortbl ;\red255\green0\blue0;}"
            + @"{\*\generator Riched20}\viewkind4\uc1\pard\f0\fs22 Hello \b bold\b0  world\par Second line\tab tabbed\par}";

        Assert.Equal("Hello bold world\nSecond line\ttabbed", RtfText.ToPlainText(rtf));
    }

    [Fact]
    public void RtfDecodesEscapes()
    {
        const string rtf = @"{\rtf1\ansi\ansicpg1252 caf\'e9 \u8364?\uc0\u8364  \{braces\} back\\slash \emdash}";

        Assert.Equal("café €€ {braces} back\\slash —", RtfText.ToPlainText(rtf));
    }

    [Fact]
    public void RtfSkipsPicturesAndFieldInstructions()
    {
        const string rtf = @"{\rtf1 Before {\pict\pngblip 89504e47} {\field{\*\fldinst HYPERLINK ""https://example.com""}{\fldrslt link}} after}";

        Assert.Equal("Before  link after", RtfText.ToPlainText(rtf));
    }

    [Fact]
    public void HtmlFormatReadsTheFragment()
    {
        const string body = "<html><body><!--StartFragment--><p>Hello &amp; <b>bye</b></p><p>Next</p><!--EndFragment--></body></html>";
        var header = "Version:0.9\r\nStartHTML:{0:D10}\r\nEndHTML:{1:D10}\r\nStartFragment:{2:D10}\r\nEndFragment:{3:D10}\r\n";
        var headerLength = string.Format(header, 0, 0, 0, 0).Length;
        var start = headerLength + body.IndexOf("<!--StartFragment-->", StringComparison.Ordinal) + "<!--StartFragment-->".Length;
        var end = headerLength + body.IndexOf("<!--EndFragment-->", StringComparison.Ordinal);
        var data = Encoding.UTF8.GetBytes(string.Format(header, headerLength, headerLength + body.Length, start, end) + body);

        Assert.Equal("Hello & bye\nNext", HtmlClipboardText.ToPlainText(data));
    }

    [Fact]
    public void FileDropListReadsWidePaths()
    {
        var paths = Encoding.Unicode.GetBytes("C:\\a.txt\0D:\\b c.png\0\0");
        var header = new byte[20];
        BitConverter.TryWriteBytes(header.AsSpan(0), 20u);
        BitConverter.TryWriteBytes(header.AsSpan(16), 1u);

        Assert.Equal(new[] { "C:\\a.txt", "D:\\b c.png" }, FileDropList.Parse(header.Concat(paths).ToArray()));
    }

    [Fact]
    public void FileDropListIgnoresBadData()
    {
        Assert.Empty(FileDropList.Parse(new byte[] { 1, 2, 3 }));
        Assert.Empty(FileDropList.Parse(new byte[24]));
    }

    [Theory]
    [InlineData("#f80", 0xFF, 0x88, 0x00, 0xFF)]
    [InlineData("#FF8800", 0xFF, 0x88, 0x00, 0xFF)]
    [InlineData(" #ff880080 ", 0xFF, 0x88, 0x00, 0x80)]
    public void HexColorsParse(string text, int r, int g, int b, int a)
    {
        Assert.True(HexColor.TryParse(text, out var color));
        Assert.Equal(new HexColor((byte)r, (byte)g, (byte)b, (byte)a), color);
    }

    [Theory]
    [InlineData("ff8800")]
    [InlineData("#ff888")]
    [InlineData("#gg8800")]
    [InlineData("#ff8800 and more")]
    public void NonColorsDoNotParse(string text)
    {
        Assert.False(HexColor.TryParse(text, out _));
    }
}

public class DibImageTests
{
    [Fact]
    public void AddsAFileHeaderPointingPastTheInfoHeader()
    {
        var dib = new byte[40 + 4];
        BitConverter.TryWriteBytes(dib.AsSpan(0), 40u);
        BitConverter.TryWriteBytes(dib.AsSpan(4), 1);
        BitConverter.TryWriteBytes(dib.AsSpan(8), 1);
        BitConverter.TryWriteBytes(dib.AsSpan(14), (ushort)32);

        var bmp = DibImage.ToBmpFile(dib)!;

        Assert.Equal((byte)'B', bmp[0]);
        Assert.Equal((byte)'M', bmp[1]);
        Assert.Equal((uint)bmp.Length, BitConverter.ToUInt32(bmp, 2));
        Assert.Equal(14u + 40u, BitConverter.ToUInt32(bmp, 10));
    }

    [Fact]
    public void CountsTheColorTableAndBitfieldMasks()
    {
        var paletted = new byte[40 + 1024 + 4];
        BitConverter.TryWriteBytes(paletted.AsSpan(0), 40u);
        BitConverter.TryWriteBytes(paletted.AsSpan(14), (ushort)8);
        var masked = new byte[40 + 12 + 4];
        BitConverter.TryWriteBytes(masked.AsSpan(0), 40u);
        BitConverter.TryWriteBytes(masked.AsSpan(14), (ushort)32);
        BitConverter.TryWriteBytes(masked.AsSpan(16), 3u);

        Assert.Equal(14u + 40u + 1024u, BitConverter.ToUInt32(DibImage.ToBmpFile(paletted)!, 10));
        Assert.Equal(14u + 40u + 12u, BitConverter.ToUInt32(DibImage.ToBmpFile(masked)!, 10));
    }

    [Fact]
    public void RejectsData_TooShortForAHeader()
    {
        Assert.Null(DibImage.ToBmpFile(new byte[8]));
    }
}
