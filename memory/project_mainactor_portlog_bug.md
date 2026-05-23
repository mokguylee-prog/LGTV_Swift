---
name: mainactor-portlog-heisenbug
description: "TVController portLog @MainActor 과부하로 verifyLGTV URLSession 타임아웃 발생 — TV 검색 결과 빈 목록 버그 (Heisenbug, 50회 이상 분석 끝에 발견)"
metadata: 
  node_type: memory
  type: project
  originSessionId: f7a63ef9-fff9-4e82-80b8-a53b442afdb5
---

## ✅ 진짜 원인 확정: build.sh codesign 누락 (아래 참조)

## 버그: TV 검색 버튼 눌러도 목록에 아무것도 안 뜸

**증상**: `discover()` 실행 후 `discoveredDevices`가 비어 있음. 코드는 컴파일 성공, v0516은 정상 동작.

**근본 원인**: `portScanOnly` progress 콜백이 IP 1개당 `Task { @MainActor }` 1개 생성 (254개 subnet 기준 254개). 각 Task가 `portLog.append` → `objectWillChange` → `ConnectionWindowView`의 `.onChange(of: tv.portLog.count)` → `proxy.scrollTo(last, anchor: .bottom)` 애니메이션 호출. 254개 애니메이션이 main actor를 수 초간 점유 → `verifyLGTV` 내부 `URLSession.data(for:)` 완료 콜백이 main actor에 복귀하지 못하고 2초 `timeoutInterval` 초과 → 모든 HTTP 검증 실패.

**왜 Heisenbug인가**: 디버그 print문을 추가하면 main actor에 실행 여유가 생겨 portLog Task들이 먼저 소화되고 verifyLGTV가 정상 동작함.

**핵심 패턴 (이 프로젝트 전반에 주의)**:
- `TVController`는 `@MainActor` 클래스
- `verifyLGTV` 내 모든 `URLSession.data(for:)` 호출은 main actor 복귀 필요
- `portLog.append` 같은 `@Published` 배열 변경이 SwiftUI `.onChange` 애니메이션을 유발하면 main actor를 수 초 점유 가능
- `timeoutInterval: 2`초 짜리 HTTP 요청은 main actor 대기 중 쉽게 타임아웃

**현재 상태**: 정확한 수정 방법 미확정. 임시 workaround로 `buildDevices` 진입 전후에 `print("[DBG] ...")` 문을 남겨 두면 정상 동작함 (Heisenbug 특성상 print문이 main actor 스케줄링 타이밍을 변화시켜 증상 해소). print문 제거 시 재현됨. 근본 fix는 추가 분석 필요.

**Why**: 정상 동작 버전(v0516)에는 portLog 자체가 없었음. portLog + 실시간 스크롤 애니메이션 UI를 추가하면서 이 문제 발생.

**How to apply**: 향후 `@Published` 배열에 고빈도 append + SwiftUI `.onChange` 애니메이션 패턴 조합을 쓸 때, main actor에서 실행되는 async HTTP 요청과 충돌하는지 반드시 검토. 특히 `URLSession` timeout이 짧은 경우 위험.
