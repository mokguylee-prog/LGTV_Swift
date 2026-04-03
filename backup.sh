#!/bin/bash
# backup.sh — 프로젝트 백업 스크립트
# 출력 파일: <프로젝트이름>_<년월일>_<시간분초>_.zip  (상위 디렉토리에 저장)
# 프로젝트 이름은 Package.swift 의 name 필드에서 자동으로 읽어옵니다.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
DIR_NAME="$(basename "$SCRIPT_DIR")"

# Package.swift 에서 프로젝트 이름 추출 (파일이 없으면 디렉토리 이름 사용)
if [[ -f "$SCRIPT_DIR/Package.swift" ]]; then
  PROJECT_NAME="$(grep -m1 'name:' "$SCRIPT_DIR/Package.swift" \
    | sed 's/.*name:[[:space:]]*"\(.*\)".*/\1/')"
else
  PROJECT_NAME="$DIR_NAME"
fi

if ! command -v zip >/dev/null 2>&1; then
  echo "오류: zip 명령어를 찾을 수 없습니다." >&2
  exit 1
fi

DATE="$(date +"%Y%m%d")"
TIME="$(date +"%H%M%S")"
ZIP_NAME="${PROJECT_NAME}_${DATE}_${TIME}_.zip"
ZIP_PATH="${PARENT_DIR}/${ZIP_NAME}"

# 중복 파일명 처리
COUNTER=2
while [[ -e "$ZIP_PATH" ]]; do
  ZIP_PATH="${PARENT_DIR}/${PROJECT_NAME}_${DATE}_${TIME}_v${COUNTER}_.zip"
  COUNTER=$((COUNTER + 1))
done

echo "▶  백업 중: $(basename "$ZIP_PATH")"

cd "$PARENT_DIR"

zip -qr "$ZIP_PATH" "$DIR_NAME" \
  -x "$DIR_NAME/.build/*"        \
  -x "$DIR_NAME/.git/*"          \
  -x "$DIR_NAME/$PROJECT_NAME"   \
  -x "$DIR_NAME/*.xcuserstate"   \
  -x "$DIR_NAME/*.xcbkptlist"    \
  -x "$DIR_NAME/**/.DS_Store"    \
  -x "$DIR_NAME/.DS_Store"       \
  -x "$DIR_NAME/__pycache__/*"   \
  -x "$DIR_NAME/*.pyc"           \
  -x "$DIR_NAME/*.zip"

echo "✓  완료: $ZIP_PATH"
