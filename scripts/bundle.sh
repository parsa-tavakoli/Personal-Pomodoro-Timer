#!/bin/bash
# Builds a release binary and wraps it into Pomodoro.app (no Xcode needed).
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Pomodoro"

APP="Pomodoro.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Pomodoro"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc sign so macOS allows notifications.
codesign --force --sign - "$APP"

echo "Built $(pwd)/$APP"
echo "Run it with: open $APP   (or drag it into /Applications)"
