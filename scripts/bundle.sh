#!/bin/bash
# Builds a universal (Apple Silicon + Intel) release binary and wraps it into
# Pomodoro.app. Works with just the Command Line Tools; no Xcode needed.
#
#   VERSION=1.2.0 ./scripts/bundle.sh   # version shown in Finder / About (default: latest git tag)
#   BUILD=42                            # optional build number (default: commit count)
set -euo pipefail
cd "$(dirname "$0")/.."

# Default version: the latest release tag (v1.0.3 -> 1.0.3), so local builds match the
# release they were made from (and the update check doesn't flag them as outdated).
TAG_VERSION="$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')"
PLIST_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
VERSION="${VERSION:-${TAG_VERSION:-$PLIST_VERSION}}"
BUILD="${BUILD:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
MIN_MACOS="26.0"

# One build per architecture, then merge them into a single universal binary.
# Each binary is copied out right away: both triples can share one output folder.
ARCH_DIR="$(mktemp -d)"
trap 'rm -rf "$ARCH_DIR"' EXIT
BINS=()
for ARCH in arm64 x86_64; do
    TRIPLE="$ARCH-apple-macosx$MIN_MACOS"
    swift build -c release --triple "$TRIPLE"
    cp "$(swift build -c release --triple "$TRIPLE" --show-bin-path)/Pomodoro" "$ARCH_DIR/Pomodoro-$ARCH"
    BINS+=("$ARCH_DIR/Pomodoro-$ARCH")
done

APP="Pomodoro.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create "${BINS[@]}" -output "$APP/Contents/MacOS/Pomodoro"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# Bundled fonts (SIL OFL), loaded automatically via ATSApplicationFontsPath in Info.plist.
cp -R Resources/Fonts "$APP/Contents/Resources/Fonts"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD" "$APP/Contents/Info.plist"

# Ad-hoc sign: required to run on Apple Silicon and for notifications.
# (With a Developer ID certificate this becomes a real signature; see release.yml.)
codesign --force --sign - "$APP"

echo "Built $(pwd)/$APP  (version $VERSION, build $BUILD, $(lipo -archs "$APP/Contents/MacOS/Pomodoro"))"
echo "Run it with: open $APP   (or drag it into /Applications)"
