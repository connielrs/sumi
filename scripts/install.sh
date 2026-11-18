#!/bin/bash
# Compila Sumi y la deja instalada en /Applications.
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build.sh

DEST=/Applications/Sumi.app
osascript -e 'tell application "Sumi" to quit' >/dev/null 2>&1 || true
rm -rf "$DEST"
cp -R build.noindex/Sumi.app "$DEST"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
# Solo la copia instalada debe aparecer en "Abrir con".
"$LSREGISTER" -u build.noindex/Sumi.app >/dev/null 2>&1 || true
"$LSREGISTER" -f "$DEST"
touch "$DEST"

echo "Instalada en $DEST"
