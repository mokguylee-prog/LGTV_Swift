---
name: mainactor-portlog-heisenbug
description: "TVController verifyLGTV @MainActor 직렬화로 TV 검색 결과 빈 목록 버그 — nonisolated 전환으로 수정 완료 (50회 이상 분석, 2026-05-23)"
metadata: 
  node_type: memory
  type: project
  originSessionId: f7a63ef9-fff9-4e82-80b8-a53b442afdb5
---

## ✅ 최종 수정 완료 (2026-05-23)

## 버그: TV 검색 버튼 눌러도 목록에 아무것도 안 뜸

**증상**: `discover()` 실행 후 `discoveredDevices`가 비어 있음. 코드는 컴파일 성공, v0516은 정상 동작.

**근본 원인 (최종 확정)**: `buildDevices` 내 `withTaskGroup` child task들이 `verifyLGTV`를 호출할 때 `@MainActor`를 통해 직렬화됨. `TVController`가 `@MainActor` 클래스이므로 `verifyLGTV`도 기본적으로 main actor 격리. `withTaskGroup` child task가 `await self.verifyLGTV(...)` 호출 시 main actor로 hop 필요 → 모든 검증 task가 사실상 직렬화 → 동시성 없이 순차 실행 → `portScanOnly` progress 콜백의 `Task { @MainActor portLog.append }` 들이 main actor queue에 쌓인 상태에서 경쟁 → verifyLGTV의 URLSession.data 콜백이 main actor 복귀 못하고 타임아웃.

**왜 Heisenbug였나**: print문이 child task 간 타이밍을 바꿔 main actor queue가 소화될 틈을 줬기 때문.

**수정 방법**: `verifyLGTV`, `isPortOpen`, `parseTag`, `looksLikeLGServer`, `looksLikePrinter`, `printerModel`을 모두 `nonisolated`로 선언.
- `nonisolated`로 선언된 async 함수를 actor-isolated 컨텍스트에서 `await` 호출하면 Swift가 cooperative thread pool로 전환 — main actor 불필요
- `session`은 `let` 속성이므로 `nonisolated`에서 안전하게 접근 가능
- 모든 `[DBG]` print 문 제거

**핵심 패턴 (이 프로젝트 전반에 주의)**:
- `@MainActor` 클래스에서 `withTaskGroup` + async HTTP 검증 패턴 쓸 때: 검증 함수를 반드시 `nonisolated`로 선언해 thread pool에서 병렬 실행되도록 할 것
- `let` 속성 (`URLSession`, 설정값 등)은 `nonisolated` 함수에서 안전하게 참조 가능
- `@Published var` 속성은 `nonisolated` 함수에서 직접 접근 불가 → 파라미터로 전달하거나 main actor에서 읽어서 넘길 것
- `portLog` 같은 `@Published` 배열 고빈도 append + SwiftUI `.onChange` 애니메이션 조합은 main actor 과부하 유발 가능 — rate limiting 유지

**Why**: 정상 동작 버전(v0516)에는 portLog 자체와 DeviceKind 검증이 없었음.

**How to apply**: 새 검증/HTTP 함수 추가 시 `nonisolated private func` 패턴 사용. `buildDevices` 구조 건드릴 때 child task에서 main actor hop 없이 동작하는지 확인.
