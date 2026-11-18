#!/bin/bash
# Compila Sumi y arma build.noindex/Sumi.app.
# La carpeta termina en .noindex para que Spotlight no muestre esta copia junto a la instalada.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP=build.noindex/Sumi.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Sumi "$APP/Contents/MacOS/Sumi"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP" >/dev/null

echo "Listo: $APP"
