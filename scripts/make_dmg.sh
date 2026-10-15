#!/bin/bash
# Packs Pomodoro.app into dist/Pomodoro-<version>.dmg with an Applications
# shortcut, so users can drag the app into Applications. Run bundle.sh first.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="Pomodoro.app"
[ -d "$APP" ] || { echo "No $APP found; run ./scripts/bundle.sh first." >&2; exit 1; }
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

mkdir -p dist
DMG="dist/Pomodoro-$VERSION.dmg"
hdiutil create -volname "Pomodoro" -srcfolder "$STAGE" -format UDZO -ov "$DMG" >/dev/null

echo "Built $(pwd)/$DMG"
