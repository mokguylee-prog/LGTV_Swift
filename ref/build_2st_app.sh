#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"
export PYINSTALLER_CONFIG_DIR="$PROJECT_DIR/.pyinstaller"

/usr/local/bin/python3 generate_lg_icon.py

PYINSTALLER_ARGS=(
  --noconfirm
  --clean
  --windowed
  --name "LG NetCast Remote 2st Menubar"
  --osx-bundle-identifier "com.kadelee.lgnetcast.2st.menubar"
  --hidden-import rumps
  --hidden-import AppKit
  --hidden-import Foundation
  --hidden-import objc
  --add-data "$PROJECT_DIR/assets:assets"
)

if [[ -f "$PROJECT_DIR/assets/LGNetCast.icns" ]]; then
  PYINSTALLER_ARGS+=(--icon "$PROJECT_DIR/assets/LGNetCast.icns")
fi

/usr/local/bin/python3 -m PyInstaller "${PYINSTALLER_ARGS[@]}" "$PROJECT_DIR/lg_remote_template_2st_menubar.py"

/usr/bin/plutil -replace LSUIElement -bool YES \
  "$PROJECT_DIR/dist/LG NetCast Remote 2st Menubar.app/Contents/Info.plist"

printf "%s\n" "$PROJECT_DIR/dist/LG NetCast Remote 2st Menubar.app"
