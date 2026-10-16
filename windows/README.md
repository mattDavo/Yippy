# Cairn for Windows

The Windows version of Cairn: a clipboard history in the notification area. Press **Ctrl+Shift+V** (configurable) to open
the panel, pick an item with the arrow keys and press **Enter**, and it's pasted into the app you were using.

It is a separate .NET 8 / WPF app that ports the macOS app's features:

- Every format on the clipboard is kept (text, rich text, HTML, images, files, app-specific formats) and pasted back as it was.
- Favourites, kept separately from the history, which you can rename and edit.
- Search with `/img`, `/link`, `/file`, `/color` and `@app` filters, and text recognition (OCR) in images.
- Source app and time on each item, ignored apps, apps whose copies expire, and deleting items after a number of days.
- Paste as plain text (Shift+Enter) or transformed (trim, case, remove link tracking, pretty-print JSON).
- Panel at any screen edge, centred or full screen, following the screen the mouse is on, in light or dark theme.
- Sync with your Macs and other PCs through your own server (Settings › Sync), end-to-end encrypted; see
  [`sync-server/`](../sync-server/README.md).
- Copies marked as private by password managers (`ExcludeClipboardContentFromMonitorProcessing`,
  `CanIncludeInClipboardHistory = 0`) are never saved.

- Win+V can open Cairn instead of Windows' own clipboard history (Settings › Shortcut › Use Win+V, or the installer's
  Win+V option), and be given back the same way. It sets Explorer's `DisabledHotkeys` setting for your user and
  restarts Explorer. [`scripts/Use-CairnForWinV.ps1`](scripts/Use-CairnForWinV.ps1) and
  [`scripts/Restore-WindowsWinV.ps1`](scripts/Restore-WindowsWinV.ps1) do the Windows side of the same change. They
  are built into `Cairn.exe` (Settings › Shortcut › Save scripts), installed in `scripts\`, and attached to each release.

Not ported: automatic updates (Sparkle is macOS-only) and the Accessibility welcome window (Windows needs no permission to paste).

## Requirements

Windows 10 1809 or later, x64. The published `Cairn.exe` is self-contained, so .NET doesn't need to be installed.

## Download and install

Every merge to `master` that changes the Windows app publishes a GitHub release tagged `windows-vX.Y.Z`
([all releases](https://github.com/Hamza-Shewa/Yippy/releases)) with:

- `Cairn-<version>-setup.exe`, the installer. It installs for your user only (no administrator rights) in
  `%LOCALAPPDATA%\Programs\Cairn`, with a Start menu shortcut and the Win+V scripts, and offers to start Cairn when you
  sign in and to hand Win+V to Cairn. Running a newer setup updates the installed copy, closing Cairn first. It also
  updates a copy installed as Yippy (version 1): it closes Yippy, removes `Yippy.exe` and its sign-in entry, and Cairn
  moves `%APPDATA%\Yippy` to `%APPDATA%\Cairn` on its first launch (`Shell/LegacyMigration`).
  Uninstalling (Settings › Apps) gives Win+V back to Windows and asks whether to delete your history too.
- `Cairn-<version>-win-x64.exe`, the same app as a single portable exe.
- The two Win+V scripts.

The version is `<Version>` in `Directory.Build.props`, or the latest `windows-v` tag with its patch number incremented;
raise `<Version>` to start a new minor or major version. Windows releases are not marked "Latest", which stays the
macOS installer. Neither exe is code-signed, so SmartScreen warns on first run (More info › Run anyway).

### Command line

`Cairn.exe` with no arguments starts Cairn (or shows the panel of the copy already running). These run without
opening a window, for the installer and for scripts; a running copy is closed first and started again afterwards:

| Command | Does |
| --- | --- |
| `Cairn.exe --use-win-v` | Takes Win+V over from Windows' clipboard history and makes it Cairn's shortcut. |
| `Cairn.exe --restore-win-v` | Gives Win+V back to Windows; Cairn's shortcut goes back to Ctrl+Shift+V if it was Win+V. |
| `Cairn.exe --quit` | Closes the running copy (it saves its history first). |

Add `--no-restart` to the Win+V commands to skip restarting Explorer; the change then takes effect at the next sign-in.
The exit code is 0 on success, 1 if the change failed (see `error.log`) and 2 if the running copy didn't quit.

## Build and run

Needs the .NET 8 SDK or newer (a newer runtime runs it too). From this folder:

```powershell
dotnet build Yippy.sln
dotnet test Yippy.sln
dotnet run --project src/Yippy.App
```

Debug builds keep their data in `%APPDATA%\Cairn Dev` and register as "Cairn Dev", so they don't touch an installed copy.
Set `CAIRN_DATA_DIR` to use another folder.

To make the single-file `Cairn.exe` (the same command the `Windows` GitHub workflow runs and uploads as an artifact):

```powershell
dotnet publish src/Yippy.App/Yippy.App.csproj -c Release -r win-x64 --self-contained `
  -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true `
  -p:EnableCompressionInSingleFile=true -p:DebugType=none -o publish
```

To build the installer, install [Inno Setup](https://jrsoftware.org/isinfo.php) 6.7 or later and, after publishing:

```powershell
iscc /DAppVersion=1.2.3 /DPublishDir=..\publish installer\Cairn.iss
```

It writes `installer\output\Cairn-1.2.3-setup.exe`. The workflow builds it the same way, then installs it, runs the
commands and uninstalls it to check them.

Everything except the app and the platform layer targets plain `net8.0`, so the unit tests also run on Linux and macOS.
Building the WPF projects on another OS works with the Microsoft-built .NET SDK (it sets `EnableWindowsTargeting`).

## Architecture

The projects and namespaces keep Yippy as the code's internal name; the product, exe, data folder and installer are
Cairn (`Yippy.App/Brand.cs`). Clean architecture, with dependencies pointing inwards:

| Project | Contents |
| --- | --- |
| `Yippy.Domain` | Items, clipboard formats, text extraction (RTF, HTML), search queries, paste transforms, settings, panel layout. No I/O. |
| `Yippy.UseCases` | Capture, paste, favourites, search, auto-clean, OCR queue, global shortcut, settings. Defines the ports (`IClipboard`, `IHistoryRepository`, `IPasteSimulator`…). |
| `Yippy.Infrastructure` | File storage of the history, JSON settings, logs. |
| `Yippy.Platform.Windows` | Win32 adapters: clipboard and its listener, `RegisterHotKey`, focus tracking and `SendInput` paste, Windows OCR, sign-in registration. |
| `Yippy.App` | WPF views and view models (MVVM), tray icon, and `CompositionRoot`, which wires everything with dependency injection. |
| `tests/Yippy.Tests` | xUnit tests of the domain, use cases and storage, over fakes of the ports. |

Data lives in `%APPDATA%\Cairn`: `history\` and `favourites\` hold a folder per item with a file per clipboard format, plus
`index.json` (order, content hashes, source app, time, names). `settings.json`, `error.log` and `warning.log` sit beside them.

The UI uses Cairn's design system ([`brand/`](../brand/README.md)) laid out like Windows 11's Fluent style.
`Yippy.App/Themes/Light.xaml`, `Dark.xaml` (colours) and `Tokens.xaml` (radii, spacing, type sizes) are generated from
`brand/tokens.json` by `brand/generate.py`, as is `Assets/AppIcon.ico`; `Fluent.xaml` holds the type ramp and control
styles every window uses, including the
keycaps (`KeyHint`) and settings cards (`SettingsCard`) in `Presentation/`. Settings has a page per area (General,
Shortcut, History, Privacy, Sync, About), each with its own view model in `ViewModels/Settings`.

Sync lives in `Yippy.Domain/Sync` (the sync key, record ids and encryption from
[`sync-server/PROTOCOL.md`](../sync-server/PROTOCOL.md)), `Yippy.UseCases/Sync` (`SyncService`, which hears what the user
does through `IHistoryActivity`, queues changes in `sync.json` and long-polls the server), `Yippy.Infrastructure/Sync`
(the HTTP client) and `Yippy.Platform.Windows/Sync` (the key, kept in `sync-key.bin` encrypted with DPAPI).
