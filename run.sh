#!/bin/bash
# run.sh — Swift 빌드 후 .app 번들로 실행
# 메뉴바 앱이므로 실행 후 상태 표시줄 아이콘을 확인하세요.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Package.swift 에서 프로젝트 이름 추출
PROJECT_NAME="$(grep -m1 'name:' Package.swift | sed 's/.*name:[[:space:]]*"\(.*\)".*/\1/')"

# 빌드 설정 (기본: debug)
CONFIG="${1:-debug}"

if [[ "$CONFIG" != "debug" && "$CONFIG" != "release" ]]; then
  echo "사용법: $0 [debug|release]" >&2
  exit 1
fi

# build.sh 로 번들 조립
bash "$SCRIPT_DIR/build.sh" "$CONFIG"

APP_DIR="$SCRIPT_DIR/${PROJECT_NAME}.app"
echo "✓  실행: $APP_DIR"
open "$APP_DIR"
