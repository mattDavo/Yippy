# Yippy for Windows

The Windows version of Yippy: a clipboard history in the notification area. Press **Ctrl+Shift+V** (configurable) to open
the panel, pick an item with the arrow keys and press **Enter**, and it's pasted into the app you were using.

It is a separate .NET 8 / WPF app that ports the macOS app's features:

- Every format on the clipboard is kept (text, rich text, HTML, images, files, app-specific formats) and pasted back as it was.
- Favourites, kept separately from the history, which you can rename and edit.
- Search with `/img`, `/link`, `/file`, `/color` and `@app` filters, and text recognition (OCR) in images.
- Source app and time on each item, ignored apps, apps whose copies expire, and deleting items after a number of days.
- Paste as plain text (Shift+Enter) or transformed (trim, case, remove link tracking, pretty-print JSON).
- Panel at any screen edge, centred or full screen, following the screen the mouse is on, in light or dark theme.
- Copies marked as private by password managers (`ExcludeClipboardContentFromMonitorProcessing`,
  `CanIncludeInClipboardHistory = 0`) are never saved.

Not ported: automatic updates (Sparkle is macOS-only) and the Accessibility welcome window (Windows needs no permission to paste).

## Requirements

Windows 10 1809 or later, x64. The published `Yippy.exe` is self-contained, so .NET doesn't need to be installed.

## Download

Every merge to `master` that changes the Windows app publishes `Yippy-<version>-win-x64.exe` as a GitHub release tagged
`windows-vX.Y.Z` ([all releases](https://github.com/Hamza-Shewa/Yippy/releases)). The version is `<Version>` in
`Directory.Build.props`, or the latest `windows-v` tag with its patch number incremented; raise `<Version>` to start a
new minor or major version. Windows releases are not marked "Latest", which stays the macOS installer. The exe isn't
code-signed, so SmartScreen warns on first run (More info › Run anyway).

## Build and run

Needs the .NET 8 SDK or newer (a newer runtime runs it too). From this folder:

```powershell
dotnet build Yippy.sln
dotnet test Yippy.sln
dotnet run --project src/Yippy.App
```

Debug builds keep their data in `%APPDATA%\Yippy Dev` and register as "Yippy Dev", so they don't touch an installed copy.
Set `YIPPY_DATA_DIR` to use another folder.

To make the single-file `Yippy.exe` (the same command the `Windows` GitHub workflow runs and uploads as an artifact):

```powershell
dotnet publish src/Yippy.App/Yippy.App.csproj -c Release -r win-x64 --self-contained `
  -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true `
  -p:EnableCompressionInSingleFile=true -p:DebugType=none -o publish
```

Everything except the app and the platform layer targets plain `net8.0`, so the unit tests also run on Linux and macOS.
Building the WPF projects on another OS works with the Microsoft-built .NET SDK (it sets `EnableWindowsTargeting`).

## Architecture

Clean architecture, with dependencies pointing inwards:

| Project | Contents |
| --- | --- |
| `Yippy.Domain` | Items, clipboard formats, text extraction (RTF, HTML), search queries, paste transforms, settings, panel layout. No I/O. |
| `Yippy.UseCases` | Capture, paste, favourites, search, auto-clean, OCR queue, global shortcut, settings. Defines the ports (`IClipboard`, `IHistoryRepository`, `IPasteSimulator`…). |
| `Yippy.Infrastructure` | File storage of the history, JSON settings, logs. |
| `Yippy.Platform.Windows` | Win32 adapters: clipboard and its listener, `RegisterHotKey`, focus tracking and `SendInput` paste, Windows OCR, sign-in registration. |
| `Yippy.App` | WPF views and view models (MVVM), tray icon, and `CompositionRoot`, which wires everything with dependency injection. |
| `tests/Yippy.Tests` | xUnit tests of the domain, use cases and storage, over fakes of the ports. |

Data lives in `%APPDATA%\Yippy`: `history\` and `favourites\` hold a folder per item with a file per clipboard format, plus
`index.json` (order, content hashes, source app, time, names). `settings.json`, `error.log` and `warning.log` sit beside them.
