#!/bin/bash
# build.sh — Swift 빌드 + .app 번들 생성 스크립트
# 프로젝트 이름은 Package.swift에서 자동으로 읽어옵니다.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BACKUP_SCRIPT="$SCRIPT_DIR/backup.sh"

# Package.swift 에서 프로젝트 이름 추출
PROJECT_NAME="$(grep -m1 'name:' Package.swift | sed 's/.*name:[[:space:]]*"\(.*\)".*/\1/')"

# 빌드 설정 (기본: release)
CONFIG="${1:-release}"
APP_VERSION="1.5"
BUILD_DATE="$(date +%Y.%m.%d)"

if [[ "$CONFIG" != "debug" && "$CONFIG" != "release" ]]; then
  echo "사용법: $0 [debug|release]" >&2
  exit 1
fi

echo "▶  $PROJECT_NAME 빌드 중... (${CONFIG})"
swift build -c "$CONFIG"

BINARY_PATH="$(swift build -c "$CONFIG" --show-bin-path)/$PROJECT_NAME"

# ── .app 번들 조립 ────────────────────────────────────────────────────────
APP_DIR="$SCRIPT_DIR/${PROJECT_NAME}.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RES_DIR="$CONTENTS/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"

# 1. 바이너리 복사
cp "$BINARY_PATH" "$MACOS_DIR/$PROJECT_NAME"

# 2. 아이콘 복사 (assets/LGNetCast.icns → AppIcon.icns)
if [[ -f "$SCRIPT_DIR/assets/LGNetCast.icns" ]]; then
  cp "$SCRIPT_DIR/assets/LGNetCast.icns" "$RES_DIR/AppIcon.icns"
fi

# 3. Info.plist 생성
BUNDLE_ID="com.kadelee.$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]')"
cat > "$CONTENTS/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${PROJECT_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${PROJECT_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>LG NetCast Remote</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleBuildDate</key>
    <string>${BUILD_DATE}</string>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsLocalNetworking</key>
        <true/>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
    <key>NSLocalNetworkUsageDescription</key>
    <string>LG NetCast TV를 검색하고 리모컨 명령을 보내기 위해 로컬 네트워크에 접근합니다.</string>
    <key>NSBonjourServices</key>
    <array>
        <string>_http._tcp</string>
        <string>_services._dns-sd._udp</string>
    </array>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

# 4. ad-hoc 코드 서명 (로컬 네트워크 TCC 권한 획득에 필요)
codesign --force --deep --sign - "$APP_DIR"

# 5. 프로젝트 루트에도 단독 바이너리 복사 (기존 동작 유지)
cp "$BINARY_PATH" "$SCRIPT_DIR/$PROJECT_NAME"

echo "✓  앱 번들: $APP_DIR"
echo "✓  바이너리: $SCRIPT_DIR/$PROJECT_NAME"

if [[ -x "$BACKUP_SCRIPT" ]]; then
  echo "▶  빌드 후 백업 실행"
  "$BACKUP_SCRIPT"
elif [[ -f "$BACKUP_SCRIPT" ]]; then
  echo "⚠️  backup.sh 실행 권한이 없어 백업을 건너뜁니다."
else
  echo "⚠️  backup.sh 를 찾을 수 없어 백업을 건너뜁니다."
fi

echo "▶  앱 실행"
open "$APP_DIR"
