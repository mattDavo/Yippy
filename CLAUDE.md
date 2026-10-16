# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Cairn (formerly Yippy, a fork of Matthew Davidson's MIT-licensed app) is a macOS menu-bar clipboard manager (Swift 5, AppKit, RxSwift, CocoaPods + Swift Package Manager; project deployment target 10.13/10.14). It only builds and runs on macOS with Xcode. There is no linter or formatter configured.

Only what users see is named Cairn. The code keeps Yippy as its internal name: the Xcode project, targets, schemes, the Swift module (`PRODUCT_MODULE_NAME = Yippy`, so storyboards and `@testable import Yippy` work), Swift types, the .NET solution, projects and namespaces, and the `Yippy.*` XAML resource keys. User-facing strings use `Brand` (`Yippy/Sources/Constants/Brand.swift`, `windows/src/Yippy.App/Brand.cs`). Keep Matthew Davidson's copyright line in `LICENSE` and the credit in the About screens and `THIRD_PARTY_NOTICES.md`.

The `windows/` folder holds a separate Windows port (C#, .NET 8, WPF); see "Windows app" at the end. `sync-server/` is the self-hosted server both apps sync through; see "Sync server".

## Build, run, test

Always open/build `Yippy.xcworkspace` (not the `.xcodeproj`). Dependencies come from two places:
- CocoaPods: `Default`, `LoginServiceKit` (from a git URL), `RxSwift`/`RxCocoa`, plus `RxBlocking`/`RxTest` for tests.
- Swift Package Manager: `HotKey` (the `mattDavo/HotKey` fork) and `Sparkle`, pinned in `Yippy.xcworkspace/xcshareddata/swiftpm/Package.resolved`.

`Pods/` is committed, so `pod install` is only needed when the `Podfile` changes. It also carries local patches (e.g. `Pods/LoginServiceKit` was edited to compile on Xcode 27), which a `pod install` would overwrite.

There are three shared schemes, each with its own build configuration and bundle id:

| Scheme | Config | Bundle id | Use |
| --- | --- | --- | --- |
| `Yippy` | Debug/Release | `com.hamzashewa.Cairn` (`Cairn.app`) | production run/archive |
| `Yippy Beta` | Beta Debug/Beta Release (`BETA` flag, different status-bar icon) | `com.hamzashewa.CairnBeta` (`Cairn Beta.app`) | day-to-day development, beta archive |
| `Yippy XCTest` | `XCTest` (`DEBUG XCTEST` flags) | `com.hamzashewa.CairnXCTest` | the only scheme that runs tests |

```sh
xcodebuild -workspace Yippy.xcworkspace -scheme "Yippy Beta" build

# all unit tests / one class / one test
xcodebuild test -workspace Yippy.xcworkspace -scheme "Yippy XCTest" -only-testing:YippyTests
xcodebuild test -workspace Yippy.xcworkspace -scheme "Yippy XCTest" -only-testing:YippyTests/HistoryCacheTests
xcodebuild test -workspace Yippy.xcworkspace -scheme "Yippy XCTest" -only-testing:YippyTests/HistoryCacheTests/testDataWhenFMReturnsNil
```

Xcode 27 rejects the project's 10.13/10.14 deployment target, and signing fails without the project team's certificate. The project settings are deliberately unchanged, so on a machine like that pass overrides on the command line:
`-destination 'platform=macOS' MACOSX_DEPLOYMENT_TARGET=12.0 CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=`.

`YippyUITests` drives the real app via XCUITest and needs the test runner to have Accessibility permission. The scheme's launch environment sets `SRCROOT`, and the UI tests forward it to the app (see "UI-test hooks" below). `create-installer.sh` builds the `.dmg` installer; its usage is in the README.

Because the app-support directory and `UserDefaults` are keyed by bundle id, Cairn, Cairn Beta and the XCTest build each have separate history, favourites and settings. On the first launch under a new bundle id, `LegacyMigration` copies the folder and settings from the old `MatthewDavidson.Yippy*` id (not in XCTest or `--uitesting` runs). `.github/workflows/macos.yml` builds the Beta app and runs `YippyTests` on pull requests.

### Design system
`brand/tokens.json` is the single source of Cairn's colours (light and dark), radii, spacing and type sizes; `brand/generate.py` writes the platform files from it (Windows `Themes/Light.xaml`, `Dark.xaml`, `Tokens.xaml`, `Assets/AppIcon.ico`, installer images; macOS `Assets.xcassets/Tokens/*.colorset`, the app/status-bar icons and `AppLogo`, and `Constants/DesignTokens.swift`) and checks text contrast. Don't edit generated files by hand, and use tokens (`DesignTokens.Color.accent`, `{DynamicResource Yippy.Accent}`, `{StaticResource Yippy.Radius.Card}`) rather than literal colours or radii. See `brand/README.md`.

## Architecture

### Singletons and wiring
`AppDelegate` creates `Controller.main = Controller(state: State.main, settings: Settings.main)`. `Controller` owns the status item/menu (including the `Updater`'s menu item) and the window controllers (history panel, preview, and lazily the welcome/help/about/settings windows). Code reaches `State.main`, `Settings.main` and `Controller.main` globally instead of through injection; only the history/model layer takes injected dependencies (which is what the unit tests mock).

`State` is the hub: RxSwift `BehaviorRelay`s for UI state (`isHistoryPanelShown`, `panelPosition`, `currentScreen`, `previewHistoryItem`, `showsRichText`, `pastesRichText`, `ignoredAppBundleIds`) plus two `History` objects (the clipboard `history` and `favourites`, each with its own `HistoryCache`) and the `PasteboardMonitor`. Windows and menu items subscribe to these relays, so e.g. toggling the panel is just `isHistoryPanelShown.accept(...)`. `State.bind` mirrors relay values back into `Settings.main` (a `Codable` struct persisted to `UserDefaults` through the `Default` pod), which is how settings persist: there are no explicit "save settings" calls for those fields. `Settings.main` reads and writes `UserDefaults` on every access. `Settings` has a hand-written `init(from:)`; a new field must be read with `decodeIfPresent` and a default, otherwise settings saved by older versions fail to decode and everything resets.

### Clipboard capture → history → disk
1. `PasteboardMonitor` polls `NSPasteboard.changeCount` every 50 ms, tracks the frontmost app, and calls `History.pasteboardDidChange(_:originBundleId:)`.
2. `History` skips the change if `originBundleId` is in `ignoredBundleIds` (the Ignored Apps setting; the change count is still recorded). The origin is the frontmost app, so a background process writing to the clipboard is attributed to whatever is in front. It drops items carrying denylisted types (password managers, `org.nspasteboard.ConcealedType`, etc.) and ignores Yippy's own `historyItemId` type. A copy whose types and bytes exactly match an existing item moves that item to the top instead of adding a duplicate (`indexOfItem(withData:)`, using a lazily filled per-item fingerprint so it doesn't re-read everything); anything else becomes a `HistoryItem(unsavedData:)` inserted at index 0 with all its types.
3. `History` mutates its in-memory array synchronously, notifies subscribers (a closure list via `History.subscribe` with a `History.Change` enum, not Rx), then calls `HistoryFileManager`, which does all disk work on one serial background queue.
4. On disk: `~/Library/Application Support/<bundle id>/history/<item UUID>/<pasteboard type raw value>` (one file per type) plus `history/order.xml`, an array of UUID strings that defines item order. Favourites use the same layout under `favourites/`: `HistoryFileManager` takes the folder as a parameter and has two shared instances, `.default` and `.favourites`. `loadHistory` reconciles the folders against the order file and alerts on mismatches. Errors/warnings also go to `error.log`/`warning.log` in the same directory via `ErrorLogger`/`WarningLogger`.
5. `HistoryItem` loads data lazily through `HistoryCache` (LRU, 100 MB). Items must be registered with the cache before `data(withId:forType:)` serves them from it; `unsavedData` holds the bytes until the file is written, then `startCaching()` drops them.

### Favourites
Favourites are a second `History` (`State.main.favourites`, no size limit). Each favourite holds its own copy of the data (`History.toggleFavourite`, in `History+Favourites.swift`), so clearing or trimming the clipboard history never removes one. In the panel, `YippyViewController` switches between the two lists through `ItemGroup` (the buttons above the table), and every `Results` value carries the `History` it came from. Every row has a heart button (`YippyItemBaseCellView.favouriteButton`, filled when `History.containsItem(withSameContentAs:)` finds the content in the favourites; that check caches a hash per item id because it runs for every drawn row) and ⌃F does the same for the selected row. The row's right-click menu offers the same toggle.

### Pasting
`YippyHistory` wraps whichever list the table is showing. `items` can be a filtered search result, so a table row is not a history index: every action goes through `historyIndex(ofRow:)`, which looks the item up by `fsId` in the full history. Don't pass a row straight to `History.deleteItem/moveItem`.

`paste(selected:plainText:)` with `plainText: true` (⇧Return, or the right-click menu's "Paste as Plain Text") writes only `HistoryItem.getUnstyledText()` (the `.string` data, else the text of the RTF) and pastes the whole item if it has no text. `paste` moves the item to the top (clipboard only; favourites keep their order), clears the pasteboard and immediately calls `history.recordPasteboardChange(withCount:)` so `History` ignores the change Yippy itself made. It then writes the item (`HistoryItem` is an `NSPasteboardWriting` using `.promised`, so data is only read when requested) and polls until Yippy is no longer the active app before synthesizing ⌘V with `Helper.pressCommandV()`. That needs the Accessibility permission, which is why the Welcome window exists. `YippyWindowController` restores the previously frontmost app when the panel closes.

### Panel UI and key handling
`Main.storyboard` instantiates `YippyWindowController` (an `NSPanel` subclass, `YippyWindow`). Its frame is driven by `combineLatest(panelPosition, currentScreen)` through `PanelPosition.getFrame`; `State` polls the mouse every 0.1 s to update `currentScreen`. `YippyViewController` combines `results` and `selected` relays and renders them in `YippyTableView` in `onAllChange`. The Ignored Apps settings tab (`IgnoredAppsSettingsViewController`) is built in code and added in `SettingsTabViewController`, not in the storyboard.

Keyboard handling has two separate systems:
- `YippyHotKey` wraps the `HotKey` package (system-wide hotkeys, with long-press repeat). The global toggle (default ⌘⇧V, stored in `Settings.toggleHotKey`) and the in-panel keys are all registered system-wide. The in-panel ones are listed in `YippyHotKeys.inPanel` and `YippyViewController` pauses all of them while the panel is hidden. A new in-panel shortcut must be added to that list, or it takes the key away from every other app.
- `KeyPressMonitor` (`NSEvent` monitors) is used only by `HotKeySettingsViewController` to record a new toggle shortcut.

### Search
`SearchEngine` runs on a serial background queue: a case-insensitive subsequence match over each item's plain text, cached per item id (items without plain text never match). Each `search` or `cancel` bumps a generation counter, so a superseded search stops early and its results are never delivered; `completion` runs on the main queue with the matching `HistoryItem`s (not indices).

### Sync
Sync sends the history and favourites to the user's other Macs and PCs through `sync-server/` (see "Sync server" below), end-to-end encrypted. The code is in `Models/Sync`:
- Platform-independent core (Foundation + CryptoKit, all `@available(macOS 10.15, *)`): `SyncKey` (the key and what HKDF derives from it), `SyncRecord` (formats, record ids, AES-GCM sealing), `SyncServer` (`HTTPSyncServer`), `SyncState` (the queue and cursor, saved in `sync.json` in the app-support directory) and `SyncEngine` (`@MainActor`; sees each history through the `SyncList` protocol). The engine's tests (`YippyTests/Sync`) need no AppKit, so they also build as a Swift package on Linux with swift-crypto (`#if canImport(CryptoKit)` picks the library).
- AppKit side: `HistorySyncList` (adapter from `History`), `SyncPasteboardMapper` (`.string`/`.rtf`/`.html`/`.png`; TIFF is sent as PNG; copied files aren't synced), `KeychainSyncKeyStore`, and `SyncCoordinator`, which `AppDelegate` starts (not in `XCTEST` builds) and the Sync settings tab (`SyncSettingsViewController`, only on 10.15+) talks to. `Settings.syncEnabled/syncServer/syncAccessKey` are saved by the coordinator, not bound to relays.
- Only what the user does is synced. `History` reports it to its `activity` (`HistoryActivity`): copies from `pasteboardDidChange`, `deleteItemByUser`, `clearByUser`, and favourite toggles, renames and edits (`History+Favourites`). Trimming to the limit, auto-clean and changes applied from other devices go through the plain `deleteItem`/`insertItem`/`clear`, so they're never sent back. A new user action must use or add a reporting method, not call the plain one.
- CryptoKit is weak-linked (`-weak_framework CryptoKit` in the Yippy target's `OTHER_LDFLAGS`) for the 10.13 deployment target. `Info.plist` allows plain HTTP to local-network servers (`NSAllowsLocalNetworking`).

### Automatic updates
`Updater` wraps Sparkle's `SPUStandardUpdaterController`. It only starts, and `Controller` only adds the "Check for Updates..." menu item, when `Info.plist` has an `https` `SUFeedURL` and a non-empty `SUPublicEDKey`. Both ship empty, so updates are off until the appcast URL and signing key are supplied; the `XCTEST` build never starts it. The release steps are in the README ("Automatic updates").

### UI-test hooks (compiled into the app)
Launching with `--uitesting` makes `AppDelegate` call `UITesting.setupUITestEnvironment`, which swaps `Helper.accessControlHelper` and `Helper.keyPressHelper` for mocks that exchange state with the test process through named pasteboards (`Yippy.UITesting.*`), and blanks `UserDefaults`. Extra launch args: `--Settings.testData=<name>` loads canned settings (`Settings.testData`, e.g. `a`, `ignoredApps`), and `--test-dir=<name>` replaces the app-support directory with a copy of `TestData/<name>` (it deletes the existing one, and needs `SRCROOT`). `Constants/Accessibility.swift` identifiers are compiled into both the app and `YippyUITests`, so changing one means both sides see it.

## Tests
Unit tests mock every system dependency (`FileManagerMock`, `ArrayFileManagerMock`, `DataFileManagerMock`, loggers, `Alerter`) and inject them through the initializers of `HistoryFileManager` and `HistoryCache`; follow that style rather than touching the real file system. `YippyTests.swift` is just Xcode's placeholder.

Several tests wait on predicate `XCTestExpectation`s. Chaining two of them through an expectation handler always timed out on current XCTest, so await each step in turn.

New source and test files must be added to `Yippy.xcodeproj/project.pbxproj`; PRs that each add files tend to conflict there.

## Windows app
`windows/` is a .NET 8 / WPF port with its own solution (`windows/Yippy.sln`) and README. It shares no code with the Swift app, so a feature added to one has to be ported to the other by hand.

```sh
cd windows
dotnet build Yippy.sln
dotnet test Yippy.sln   # xUnit, runs on any OS
```

- Layers: `Yippy.Domain` (pure) <- `Yippy.UseCases` (services plus the ports in `Abstractions/Ports.cs`) <- `Yippy.Infrastructure` (files) and `Yippy.Platform.Windows` (Win32) <- `Yippy.App` (WPF/MVVM). `Yippy.App/CompositionRoot.cs` is the only place that names concrete adapters. Domain, UseCases, Infrastructure and the tests target plain `net8.0`; keep Windows APIs out of them.
- `Directory.Build.props` turns warnings into errors and sets `EnableWindowsTargeting`, so the WPF projects compile on Linux with the Microsoft-built SDK (Ubuntu's own `dotnet-sdk` package lacks the WindowsDesktop SDK). The app itself only runs on Windows.
- Tests use the fakes in `tests/Yippy.Tests/Fakes` (`TestApp` wires the use cases like the composition root does).
- `GetClipboardSequenceNumber` plays the role of `NSPasteboard.changeCount`; Yippy records the number after its own writes so they aren't captured. Formats are stored by name (`CF_UNICODETEXT`, `Rich Text Format`, registered names).
- Win+V belongs to Explorer. `WindowsClipboardShortcutService` takes it over by adding "V" to `HKCU\...\Explorer\Advanced\DisabledHotkeys` (`ExplorerClipboardShortcut`), restarting Explorer, then registering Win+V as the toggle; restoring reverses the order. `windows/scripts/*.ps1` do the registry side by hand, and CI runs them with `-NoRestart`.
- New settings go in `AppSettings` with a default; the JSON reader fills missing fields from the defaults, so older settings files still load.
- `Yippy.App/Program.cs` is the entry point. The commands `--use-win-v`, `--restore-win-v` and `--quit` (`CommandLine`, run by `Shell/CommandRunner` through `WindowsClipboardShortcutSetup`) are handled there before WPF starts, so they work headless; a running copy is told to quit (`Shell/SingleInstance`: the `Local\Cairn.Instance` mutex plus show/quit events) and relaunched afterwards. The installer and uninstaller rely on them.
- The `.ps1` scripts are embedded in `Yippy.Platform.Windows` (`EmbeddedClipboardShortcutScripts`) for Settings > Shortcut > Save scripts; edit them in `windows/scripts/` only.
- `windows/installer/Cairn.iss` is the Inno Setup installer: per user (no admin), Start menu, optional sign-in and Win+V tasks, uninstall restores Win+V and asks before deleting `%APPDATA%\Cairn`. It keeps Yippy's AppId so it updates a Yippy 1.x install (removing `Yippy.exe` and its sign-in entry). Keep its `InstanceMutex` in step with `App.InstanceName`. `Program.Main` runs `Shell/LegacyMigration` first, which closes a running Yippy and moves `%APPDATA%\Yippy` and its sign-in entry over once.
- UI: `Themes/Light.xaml`/`Dark.xaml` are colour tokens and `Themes/Tokens.xaml` radii, spacing and type sizes (all generated from `brand/tokens.json`), `Themes/Fluent.xaml` the fonts, text styles and control styles; use those keys (`Yippy.*`) rather than literal values. Settings is one window with a page view model per area in `ViewModels/Settings` (navigate with `IAppNavigation.ShowSettings(SettingsPage)`); page views are in `Views/Settings`.
- Sync (`Domain/Sync`, `UseCases/Sync`, `Infrastructure/Sync`, `Platform.Windows/Sync`, Settings > Sync) follows the same protocol and rules as the Mac's `SyncEngine`; `SyncService` implements `IHistoryActivity`, which `ClipboardCaptureService` and `HistoryEditingService` call for user actions only. The key is in `sync-key.bin` (DPAPI), the queue in `sync.json`.
- `.github/workflows/windows.yml` builds, tests and publishes `Cairn.exe` on `windows-latest`, builds the installer with Inno Setup (from the `tools.innosetup` NuGet package), and installs, exercises and uninstalls it. On `master` it also creates a `windows-vX.Y.Z` GitHub release (not marked Latest) with the setup, the portable exe and the scripts, whose version comes from `<Version>` in `windows/Directory.Build.props` or the next patch after the latest `windows-v` tag. `release.yml` (macOS, `v` tags) ignores `windows/**`.

## Sync server
`sync-server/` is the relay both apps sync through: an ASP.NET Core minimal API (.NET 8) over SQLite, deployed with Docker Compose behind Caddy (its README has the VPS steps and settings). `PROTOCOL.md` is the contract all three implement; change it first. Layers: `Domain` <- `Application` (`SyncService`, the `ISyncStore` port) <- `Infrastructure` (`SqliteSyncStore`, `RetentionWorker`) and `Api` (endpoints). `.github/workflows/sync-server.yml` tests it and builds the image.

```sh
cd sync-server && dotnet test SyncServer.sln
```

`test-vectors.json` is shared by the Windows tests (which write it with `SYNC_WRITE_TEST_VECTORS=1`) and the Mac's `SyncCoreTests` (which find it relative to their source file, or at `SYNC_TEST_VECTORS`), so every implementation agrees on keys, ids and encryption.
