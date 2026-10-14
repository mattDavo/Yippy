# Yippy
macOS open source clipboard manager

![screenshot](images/screenshot.jpg)

Follow progress at <a href="https://yippy.mattdavo.com" target="_blank">yippy.mattdavo.com</a>

Read about the progress and learnings at <a href="https://yippy.mattdavo.com/blog" target="_blank">yippy.mattdavo.com/blog</a>

Find all releases at <a href="https://yippy.mattdavo.com/releases" target="_blank">yippy.mattdavo.com/releases</a>

## Installation
Downloaded from <a href="https://yippy.mattdavo.com" target="_blank">yippy.mattdavo.com</a> or install with [Homebrew Cask](https://github.com/Homebrew/homebrew-cask):
```
brew install --cask yippy
```

For help with installation see: <a href="https://yippy.mattdavo.com/installation" target="_blank">yippy.mattdavo.com/installation</a>.

### Windows
A Windows version lives in [`windows/`](windows/README.md). Download `Yippy-<version>-setup.exe` (the installer) or `Yippy-<version>-win-x64.exe` (portable) from the newest `windows-v` release on the [releases page](https://github.com/Hamza-Shewa/Yippy/releases).

## Developing Yippy
### Contributions
All contributions are welcome, whether they are pull requests, bug reports, feature requests or general feedback.

### Project Structure
There are 3 different schemes:
- Yippy
- Yippy Beta
- Yippy XCTest

__Yippy__ is used for running and archiving a production build of Yippy. __Yippy Beta__ is used for development and archiving a beta release. __Yippy XCTest__ is used exclusively for running the unit and UI tests.

### Building an installer with `create-installer.sh`
`./create-installer.sh` archives Yippy (Release, universal Intel + Apple Silicon), signs it and packages it as `build/installer/Yippy-<version>.dmg` with the app and an Applications shortcut to drag it onto. It only needs Xcode; if [create-dmg](https://github.com/create-dmg/create-dmg) is installed (`brew install create-dmg`) it's used for a nicer window layout.

```
./create-installer.sh                          # ad-hoc signed, for this Mac
./create-installer.sh --scheme "Yippy Beta"    # beta build
./create-installer.sh --sign "Developer ID Application: Name (TEAMID)" --notarize PROFILE
./create-installer.sh --app path/to/Yippy.app  # package an existing build
```

To share the installer, sign it with a Developer ID Application certificate and notarize it. Otherwise Gatekeeper blocks it on other Macs. Create the notary profile once with `xcrun notarytool store-credentials PROFILE`. `--appcast DIR` copies the `.dmg` into your releases folder and runs Sparkle's `generate_appcast` (see "Automatic updates"). Run `./create-installer.sh --help` for every option.

### Automatic releases
`.github/workflows/release.yml` runs on every push or merge to `master` (except changes to Markdown files). It builds the installer with `create-installer.sh` and publishes it as a GitHub release with a generated changelog. The version is `MARKETING_VERSION` from the Xcode project if no tag for it exists yet, otherwise the latest tag with its patch number incremented, so ordinary merges give 2.8.2, 2.8.3 and so on. To start a new minor or major version, raise `MARKETING_VERSION` above the latest tag. The build number (`CFBundleVersion`) is the workflow run number. Releases are ad-hoc signed; add a Developer ID certificate and notarization to the workflow to ship installers that open on other Macs without a Gatekeeper warning.

### Automatic updates
Yippy uses [Sparkle](https://sparkle-project.org) for updates. It stays switched off (no updater, no "Check for Updates..." menu item) until `SUFeedURL` and `SUPublicEDKey` in `Yippy/Supporting Files/Info.plist` are filled in. To turn it on:

1. Build the project once so Swift Package Manager fetches Sparkle, then find its tools under `~/Library/Developer/Xcode/DerivedData/Yippy-*/SourcePackages/artifacts/sparkle/Sparkle/bin`.
2. Run `./generate_keys` once. It stores the EdDSA private key in your login Keychain and prints the public key. Put the public key in `SUPublicEDKey`. Keep the private key safe; every future update must be signed with it.
3. Choose where the appcast will live (an `https` URL, e.g. `https://yippy.mattdavo.com/appcast.xml`) and put it in `SUFeedURL`.
4. For each release: archive and notarize Yippy as usual, put the `.dmg` (or a `.zip` of the app) in a folder with the previous releases, and run `./generate_appcast <folder>`. It signs the archives and writes `appcast.xml`. Upload the archives and `appcast.xml` to the URLs the appcast points at.
5. Bump `CFBundleVersion` (`CURRENT_PROJECT_VERSION`) for every release; Sparkle compares it to decide what's newer.

### TODO
- [ ] Support more types of pasteboard items
- [ ] Allow setting preferences for keyboard shortcuts
    - [x] Customize toggle hotkey
- [ ] Automatic updates (Sparkle is integrated; needs the appcast URL and signing key, see above)
- [ ] Create a bug reporter, if places in code are reached that should not be possible create a unique error and a prompt to report the bug.
- [ ] Don’t let any of the app be used until access is granted
- [x] Toggle for attributed text
- [x] Launch at login
- [x] Convert history storage to storing each piece of data into a file organised by directory of indexes
- [x] Favourites (click the heart on an item, or press ⌃F in the panel, to add or remove it)
- [x] Paste as plain text (⇧Return in the panel, or right-click an item)
- [ ] Search (https://github.com/krisk/fuse-swift)
- [x] Max history length
- [ ] Cell height cache improvements. Will improve window size changes and launch time.
    - [ ] Find a cheap way to clear the cell height cache
    - [ ] Store cell heights on disk
