#!/bin/bash
#
# Builds Cairn and packages it as a drag-to-Applications disk image (.dmg).
#
#   ./create-installer.sh                      # Release build of the "Yippy" scheme (Cairn.app), ad-hoc signed
#   ./create-installer.sh --scheme "Yippy Beta"
#   ./create-installer.sh --sign "Developer ID Application: Name (TEAMID)" --notarize yippy-notary
#   ./create-installer.sh --app path/to/Cairn.app   # package an existing build
#
# Run with --help for every option. Only Xcode's command line tools are required;
# if create-dmg (brew install create-dmg) is installed it is used for a nicer window layout.

set -euo pipefail

usage() {
    cat <<EOF
Usage: $0 [options]

Options:
  --scheme NAME              Scheme to build: "Yippy" (default) or "Yippy Beta".
  --app PATH                 Package this .app instead of building one.
  --output DIR               Where to write the .dmg (default: ./build/installer).
  --sign IDENTITY            Code signing identity, e.g. "Developer ID Application: Name (TEAMID)".
                             Default "-" (ad-hoc): runs on this Mac, but Gatekeeper blocks it elsewhere.
  --notarize PROFILE         Notarize and staple the .dmg using a notarytool keychain profile
                             (create one with: xcrun notarytool store-credentials PROFILE).
                             Needs a Developer ID --sign identity.
  --deployment-target VER    Override MACOSX_DEPLOYMENT_TARGET for the build. Defaults to the
                             project's value, or 12.0 on Xcode 26+ which rejects older targets.
  --version VER              Build with this CFBundleShortVersionString (MARKETING_VERSION) instead of the project's.
  --build-number N           Build with this CFBundleVersion (CURRENT_PROJECT_VERSION). Sparkle compares it to find newer releases.
  --appcast DIR              Copy the .dmg into DIR (your folder of releases) and run Sparkle's
                             generate_appcast on it to update DIR/appcast.xml.
  -h, --help                 Show this help.
EOF
}

# MARK: - Options

SCHEME="Yippy"
APP_PATH=""
OUTPUT_DIR=""
SIGN_IDENTITY="-"
NOTARY_PROFILE=""
DEPLOYMENT_TARGET=""
VERSION_OVERRIDE=""
BUILD_NUMBER=""
APPCAST_DIR=""

while [ $# -gt 0 ]; do
    case "$1" in
        --scheme) SCHEME="$2"; shift 2 ;;
        --app) APP_PATH="$2"; shift 2 ;;
        --output) OUTPUT_DIR="$2"; shift 2 ;;
        --sign) SIGN_IDENTITY="$2"; shift 2 ;;
        --notarize) NOTARY_PROFILE="$2"; shift 2 ;;
        --deployment-target) DEPLOYMENT_TARGET="$2"; shift 2 ;;
        --version) VERSION_OVERRIDE="$2"; shift 2 ;;
        --build-number) BUILD_NUMBER="$2"; shift 2 ;;
        --appcast) APPCAST_DIR="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
done

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT/build"
OUTPUT_DIR="${OUTPUT_DIR:-$BUILD_DIR/installer}"

step() { printf '\n==> %s\n' "$*"; }
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }

if [ -n "$NOTARY_PROFILE" ] && [ "$SIGN_IDENTITY" = "-" ]; then
    fail "--notarize needs a Developer ID identity passed with --sign."
fi

# MARK: - Build

if [ -z "$APP_PATH" ]; then
    case "$SCHEME" in
        "Yippy") CONFIGURATION="Release" ;;
        "Yippy Beta") CONFIGURATION="Beta Release" ;;
        *) fail "Unknown scheme '$SCHEME'. Use \"Yippy\" or \"Yippy Beta\"." ;;
    esac

    BUILD_SETTINGS=(
        # Built unsigned-ish (ad-hoc) and signed properly below, so no certificate for the
        # project's team is needed on this Mac.
        CODE_SIGN_IDENTITY=-
        CODE_SIGN_STYLE=Manual
        DEVELOPMENT_TEAM=
    )
    if [ -z "$DEPLOYMENT_TARGET" ]; then
        XCODE_MAJOR="$(xcodebuild -version | awk 'NR==1 { split($2, v, "."); print v[1] }')"
        if [ "${XCODE_MAJOR:-0}" -ge 26 ]; then
            DEPLOYMENT_TARGET="12.0"
            echo "Note: Xcode $XCODE_MAJOR rejects the project's deployment target, building for macOS $DEPLOYMENT_TARGET+."
        fi
    fi
    if [ -n "$DEPLOYMENT_TARGET" ]; then
        BUILD_SETTINGS+=(MACOSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET")
    fi

    if [ -n "$VERSION_OVERRIDE" ]; then
        BUILD_SETTINGS+=(MARKETING_VERSION="$VERSION_OVERRIDE")
    fi
    if [ -n "$BUILD_NUMBER" ]; then
        BUILD_SETTINGS+=(CURRENT_PROJECT_VERSION="$BUILD_NUMBER")
    fi

    ARCHIVE="$BUILD_DIR/$SCHEME.xcarchive"
    step "Archiving $SCHEME ($CONFIGURATION)"
    rm -rf "$ARCHIVE"
    xcodebuild archive \
        -workspace "$ROOT/Yippy.xcworkspace" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination "generic/platform=macOS" \
        -archivePath "$ARCHIVE" \
        "${BUILD_SETTINGS[@]}" \
        -quiet

    APP_PATH="$(find "$ARCHIVE/Products/Applications" -maxdepth 1 -name '*.app' | head -n 1)"
    [ -n "$APP_PATH" ] || fail "No .app found in $ARCHIVE."
fi

[ -d "$APP_PATH" ] || fail "App not found: $APP_PATH"

APP_NAME="$(basename "$APP_PATH" .app)"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo 0)"
DMG_BASENAME="$(echo "$APP_NAME" | tr ' ' '-')-$VERSION"

STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$STAGING"
mkdir -p "$STAGING" "$OUTPUT_DIR"
ditto "$APP_PATH" "$STAGING/$APP_NAME.app"
APP="$STAGING/$APP_NAME.app"

# MARK: - Sign

# Sign inside-out: nested helpers and frameworks first, the app last. Hardened runtime and a
# secure timestamp are required for notarization (not available for ad-hoc signatures).
sign() {
    if [ "$SIGN_IDENTITY" = "-" ]; then
        codesign --force --sign - "$@"
    else
        codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$@"
    fi
}

step "Signing with identity: $SIGN_IDENTITY"
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
if [ -d "$SPARKLE" ]; then
    # Sparkle's helpers, in the order its documentation gives
    for helper in \
        "$SPARKLE/Versions/B/XPCServices/Installer.xpc" \
        "$SPARKLE/Versions/B/XPCServices/Downloader.xpc" \
        "$SPARKLE/Versions/B/Autoupdate" \
        "$SPARKLE/Versions/B/Updater.app"; do
        if [ -e "$helper" ]; then
            if [[ "$helper" == *Downloader.xpc ]] && [ "$SIGN_IDENTITY" != "-" ]; then
                sign --preserve-metadata=entitlements "$helper"
            else
                sign "$helper"
            fi
        fi
    done
fi
if [ -d "$APP/Contents/Frameworks" ]; then
    find "$APP/Contents/Frameworks" -maxdepth 1 \( -name '*.framework' -o -name '*.dylib' \) -print0 |
        while IFS= read -r -d '' framework; do sign "$framework"; done
fi
ENTITLEMENTS="$ROOT/Yippy/Supporting Files/Yippy.entitlements"
sign --entitlements "$ENTITLEMENTS" "$APP"
codesign --verify --deep --strict "$APP"

# MARK: - Disk image

DMG="$OUTPUT_DIR/$DMG_BASENAME.dmg"
rm -f "$DMG"
step "Creating $DMG"
if command -v create-dmg >/dev/null 2>&1; then
    # create-dmg exits with 2 when it couldn't set the Finder layout (e.g. no Automation
    # permission); the image is still usable.
    create-dmg \
        --volname "$APP_NAME Installer" \
        --window-pos 200 120 \
        --window-size 800 400 \
        --icon-size 100 \
        --icon "$APP_NAME.app" 200 190 \
        --hide-extension "$APP_NAME.app" \
        --app-drop-link 600 185 \
        --no-internet-enable \
        "$DMG" "$STAGING" || [ $? -eq 2 ]
else
    ln -s /Applications "$STAGING/Applications"
    hdiutil create \
        -volname "$APP_NAME Installer" \
        -srcfolder "$STAGING" \
        -fs HFS+ \
        -format UDZO \
        -imagekey zlib-level=9 \
        -ov "$DMG" >/dev/null
fi
[ -f "$DMG" ] || fail "Disk image was not created."

if [ "$SIGN_IDENTITY" != "-" ]; then
    codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"
fi

# MARK: - Notarize

if [ -n "$NOTARY_PROFILE" ]; then
    step "Notarizing (this can take a few minutes)"
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
    spctl --assess --type open --context context:primary-signature --verbose "$DMG"
fi

hdiutil verify "$DMG" >/dev/null 2>&1 || fail "Disk image failed verification."

# MARK: - Appcast

if [ -n "$APPCAST_DIR" ]; then
    GENERATE_APPCAST="$(find ~/Library/Developer/Xcode/DerivedData -path '*/artifacts/sparkle/Sparkle/bin/generate_appcast' 2>/dev/null | head -n 1)"
    [ -n "$GENERATE_APPCAST" ] || fail "generate_appcast not found. Build the project once so Swift Package Manager fetches Sparkle."
    step "Updating appcast in $APPCAST_DIR"
    mkdir -p "$APPCAST_DIR"
    cp "$DMG" "$APPCAST_DIR/"
    "$GENERATE_APPCAST" "$APPCAST_DIR"
fi

rm -rf "$STAGING"

step "Done"
echo "$DMG ($(du -h "$DMG" | cut -f1))"
if [ "$SIGN_IDENTITY" = "-" ]; then
    echo "Ad-hoc signed: fine for this Mac. To share it, sign with a Developer ID (--sign) and notarize (--notarize)."
fi
