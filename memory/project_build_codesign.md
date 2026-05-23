---
name: build-codesign-localnetwork
description: build.sh로 만든 .app에서 TV/프린터 검색 안 되는 문제 — codesign 누락이 원인. swift run은 되고 .app은 안 되면 이 문제 확인.
metadata: 
  node_type: memory
  type: project
  originSessionId: f7a63ef9-fff9-4e82-80b8-a53b442afdb5
---

## 버그: build.sh .app 번들에서 네트워크 검색 완전 실패

**증상**: `swift run`으로 실행하면 네트워크 허용 다이얼로그 뜨고 허용 후 TV 정상 검색. `build.sh`로 만든 `.app`은 다이얼로그도 안 뜨고 TV/프린터 아무것도 못 찾음.

**진짜 원인**: `build.sh`에 `codesign` 단계 없음 → macOS가 앱 번들을 제대로 식별 못함 → TCC(로컬 네트워크 프라이버시) 권한 다이얼로그 표시 안 됨 → 소켓 접근(UDP 멀티캐스트, TCP 포트스캔, URLSession) 전부 차단.

**오해하기 쉬운 점**: 증상이 코드 버그처럼 보임. 50회 이상 코드 분석해도 발견 안 됨. `swift run` vs `.app` 동작 차이에서 단서 찾아야 함.

**Why**: ad-hoc 서명(`codesign --sign -`)이 없으면 macOS Sonoma(14+)에서 `.app` 번들의 로컬 네트워크 TCC 권한이 정상 동작하지 않음.

**수정** ([build.sh](../build.sh)):
```bash
# 4. ad-hoc 코드 서명
codesign --force --deep --sign - "$APP_DIR"

# TCC 권한 초기화 (서명 변경 시 기존 캐시 제거)
tccutil reset LocalNetwork "$BUNDLE_ID" 2>/dev/null || true
```

**How to apply**: 
- 빌드스크립트가 있는 프로젝트에서 `swift run`은 되는데 빌드된 `.app`에서 네트워크가 안 된다면 → 즉시 codesign 단계 확인
- 빌드 후 처음 실행 시 "로컬 네트워크 접근 허용" 다이얼로그가 뜨면 정상
- `tccutil reset LocalNetwork <bundleID>` 로 권한 초기화 가능
