namespace Yippy.Domain.Clipboard;

/// <summary>
/// Names of the clipboard formats Yippy understands.
/// </summary>
/// <remarks>
/// Standard Win32 formats are named after their <c>CF_</c> constant and registered formats by their registered name,
/// so every format of a copy can be stored under its name and written back exactly as it was copied.
/// </remarks>
public static class ClipboardFormats
{
    public const string UnicodeText = "CF_UNICODETEXT";
    public const string Dib = "CF_DIB";
    public const string DibV5 = "CF_DIBV5";
    public const string FileDrop = "CF_HDROP";
    public const string Rtf = "Rich Text Format";
    public const string Html = "HTML Format";
    public const string Png = "PNG";
    public const string Url = "UniformResourceLocatorW";
    public const string UrlAnsi = "UniformResourceLocator";

    /// <summary>
    /// Formats an app adds to say the copy must not be kept by clipboard managers, e.g. a password manager copying a password.
    /// </summary>
    public static readonly IReadOnlySet<string> OptOutMarkers = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
    {
        "ExcludeClipboardContentFromMonitorProcessing",
        "Clipboard Viewer Ignore",
    };

    /// <summary>
    /// Holds a DWORD; 0 means the copy must not go into clipboard history (Windows' own Win+V history honours it too).
    /// </summary>
    public const string CanIncludeInClipboardHistory = "CanIncludeInClipboardHistory";

    /// <summary>
    /// Formats that describe how the copy may be used rather than what was copied. They are never stored.
    /// </summary>
    public static readonly IReadOnlySet<string> PolicyFormats = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
    {
        CanIncludeInClipboardHistory,
        "CanUploadToCloudClipboard",
        "ExcludeClipboardContentFromMonitorProcessing",
        "Clipboard Viewer Ignore",
    };

    /// <summary>Formats that hold styling, left out when pasting rich text is turned off.</summary>
    public static readonly IReadOnlySet<string> RichTextFormats = new HashSet<string>(StringComparer.Ordinal)
    {
        Rtf,
        Html,
    };

    public static bool IsImage(string format) => format is Png or Dib or DibV5;

    /// <summary>Whether the app that copied this asked clipboard managers not to keep it.</summary>
    public static bool IsOptedOut(ClipboardContent content)
    {
        if (content.FormatNames.Any(OptOutMarkers.Contains))
        {
            return true;
        }
        var canInclude = content.Get(CanIncludeInClipboardHistory);
        return canInclude is { Length: >= 4 } && BitConverter.ToUInt32(canInclude, 0) == 0;
    }

    /// <summary>The content without the formats that are only there to describe how it may be used.</summary>
    public static ClipboardContent WithoutPolicyFormats(ClipboardContent content)
    {
        return content.Without(PolicyFormats.Contains);
    }
}
