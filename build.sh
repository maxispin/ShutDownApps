#!/bin/bash
# Kääntää ShutDownApps.app-paketin build-hakemistoon.
# ./build.sh install  — kopioi lisäksi /Applications-kansioon ja käynnistää.
set -euo pipefail
cd "$(dirname "$0")"

APP=build/ShutDownApps.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"

swift tools/MakeIcon.swift build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

swiftc -O -swift-version 5 -target "$(uname -m)-apple-macos14.0" \
    Sources/*.swift -o "$APP/Contents/MacOS/ShutDownApps"

codesign --force --sign - "$APP"
echo "Valmis: $APP"

if [[ "${1:-}" == "install" ]]; then
    pkill -x ShutDownApps || true
    rm -rf /Applications/ShutDownApps.app
    cp -R "$APP" /Applications/
    open /Applications/ShutDownApps.app
    echo "Asennettu: /Applications/ShutDownApps.app"
fi
