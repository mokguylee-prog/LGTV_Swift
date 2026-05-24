# LG NetCast Remote — 기술 사양서 (SPEC)

> 버전 v1.6 · 최종 수정 2026-05-25

---

## 1. 개요

| 항목 | 내용 |
|---|---|
| 앱 이름 | LG NetCast Remote |
| 플랫폼 | macOS 13 Ventura 이상 |
| 아키텍처 | SwiftUI MenuBarExtra + SPM (App Sandbox 비활성) |
| 대상 기기 | LG NetCast TV 2014년 이전 모델 (HDCP API, port 8080) |
| 언어 | Swift 5.9+ |
| 동시성 | Swift Concurrency (`async/await`, `actor`, `@MainActor`) |

---

## 2. 아키텍처 개요

```
MenuBarView / RemoteView / WheelView / MouseRemoteView
        ↓  calls async methods (@MainActor)
  TVController   (ObservableObject)
        ↓  URLSession HTTP POST  +  BSD raw sockets
  LG TV (http://<ip>:8080/hdcp/api)
```

### 주요 설계 원칙

- **단방향 데이터 흐름**: `TVController` @Published 상태 → SwiftUI 뷰 자동 갱신
- **actor 격리**: `SSDPDiscovery`는 `actor`로 선언, 소켓 작업 격리
- **nonisolated 소켓**: `isPortOpen`, `checkPort` 등 BSD 소켓 작업은 `nonisolated`로 분리해 백그라운드 Task에서 실행
- **파일 분해**: 각 파일 ~5KB, 관심사별 `+Extension` 파일로 분리

---

## 3. TV 통신 프로토콜

### 3.1 공통 HTTP 헤더

| 헤더 | 값 |
|---|---|
| Method | POST |
| Content-Type | `application/atom+xml` |
| Accept | `application/atom+xml` |
| User-Agent | `iPhone` |
| Connection | `close` (기본) / `Keep-Alive` (터치패드 이동 시) |

Base URL: `http://<ip>:8080/hdcp/api`

### 3.2 인증 흐름

```
클라이언트                         LG TV
    │                               │
    │── POST /hdcp/api/auth ────────▶│  AuthKeyReq
    │                               │  (TV 화면에 PIN 표시)
    │◀─ 200 OK ─────────────────────│
    │                               │
    │── POST /hdcp/api/auth ────────▶│  AuthReq + PIN
    │◀─ 200 OK  <session>TOKEN</session>
    │                               │
    │  (session token 저장)          │
```

### 3.3 키 입력

```xml
POST /hdcp/api/dtv_wifirc  (또는 /hdcp/api/command)

<?xml version="1.0" encoding="utf-8"?>
<command>
    <session>SESSION_TOKEN</session>
    <type>HandleKeyInput</type>
    <value>KEY_CODE</value>
</command>
```

두 엔드포인트를 순서대로 시도. 세션 만료 시 자동 재인증.

### 3.4 터치패드 명령

| type | 필드 | 설명 |
|---|---|---|
| `HandleTouchMove` | `<x>dx</x><y>dy</y>` | 상대 이동 (TV 해상도 기준 픽셀) |
| `HandleTouchClick` | — | 좌클릭 |
| `HandleTouchWheel` | `<value>up\|down</value>` | 스크롤 (일부 모델 미지원) |

커서 활성화: 실제 CursorVisible 명령 미지원 → 미세 이동(±1px) 왕복으로 커서 깨움.

---

## 4. 기기 탐색 (SSDPDiscovery)

### 4.1 탐색 전략 (병렬 실행)

```
┌─────────────────────────────────────────┐
│  SSDP M-SEARCH (UDP 239.255.255.250:1900)│ ── 동시 실행
│  B-SEARCH (UDP 255.255.255.255:1990)    │
└────────────────┬────────────────────────┘
                 │ + 포트 스캔 병렬 실행
┌────────────────▼────────────────────────┐
│  TCP Port 8080 스캔 (동시 50개)          │
│  활성 NIC 전체 /24 서브넷               │
└────────────────┬────────────────────────┘
                 │
┌────────────────▼────────────────────────┐
│  후보 IP별 검증 (병렬)                   │
│  1. UPnP LOCATION XML 파싱              │
│  2. 루트 페이지 Server 헤더              │
│  3. /hdcp/api 응답 코드                 │
└─────────────────────────────────────────┘
```

### 4.2 기기 분류

| 종류 | 판별 기준 |
|---|---|
| `lgTV` | manufacturer=LG + TV hint, 또는 Server에 LG/NETCAST/UDAP, 또는 본문에 HDCP/NETCAST |
| `printer` | Server에 HP HTTP / EPSON / CANON 등 |
| `unknown` | 포트 열림 확인만 된 경우 |

### 4.3 포트 확인 구현

macOS `SO_SNDTIMEO`는 `connect()`에 미적용 → **non-blocking socket + `select()`** 로 타임아웃 직접 제어.

```swift
// 소켓 non-blocking 설정 → connect() → EINPROGRESS → select() → getsockopt(SO_ERROR)
```

---

## 5. 컴포넌트 상세

### 5.1 TVController

`@MainActor ObservableObject`. 모든 UI 상태의 단일 진실 공급원.

| 확장 파일 | 책임 |
|---|---|
| `TVController.swift` | 상태 선언 · init · isPortOpen · 공유 헬퍼 (post/parseTag/setError) |
| `+Auth` | requestPIN / connect |
| `+Keys` | sendKey / sendKeyCode / sendLegacyTouchCommand |
| `+Mouse` | setMouseCursorVisible / sendMouseMove / sendMouseClick / sendMouseWheel |
| `+Discovery` | discover / selectDevice / buildDevices / orderDevices |
| `+Verify` | verifyLGTV / looksLikeLGServer / looksLikePrinter |

### 5.2 RemoteView

WPF RemoteWindow.xaml 디자인 재현. `SkinBtn` + `CircleBtn` 두 가지 버튼 타입.

| 확장 파일 | 내용 |
|---|---|
| `+Palette` | Color 팔레트 (`appBg`, `darkBg` 등) · `K` 키코드 enum · 레이아웃 상수 |
| `+Buttons` | `SkinBtn` (둥근 사각) · `CircleBtn` · `RemoteModeButton` · `gap()` |
| `+LeftSection` | 숫자패드 · RATIO/INPUT/TV · VOL/MUTE/CH 사이드 그룹 |
| `+RightSection` | 방향키 패드 · GUIDE · 색상 버튼 · 미디어 · INFO · REC |

### 5.3 WheelView

| 확장 파일 | 내용 |
|---|---|
| `+FrictionSlider` | 수직 슬라이더 (마찰 계수 0.90~0.99 조절) |
| `+CylinderWheel` | V1 트림 휠: 드래그 · 관성(Task 루프 · @State 직접 변경) · 스크롤 휠 |
| `+DialWheel` | V2 원형 다이얼: Canvas tick marks · 속도 적응 스텝 |
| `+ScrollCatcher` | `NSViewRepresentable` → `scrollWheel(with:)` 이벤트 포워딩 |

#### 관성 알고리즘 (CylinderWheelControl)

```
속도 계산: 마지막 80ms 위치 윈도우 기준 (px/s)
감쇠: vel *= friction^(dt×60)   // 프레임레이트 독립
임계값: |vel| < 0.5 → 종료
키 트리거: 누적 offset이 basePx(22px) 단위 초과 시 sendKey
```

### 5.4 MouseTrackingPad

절대좌표 맵핑 방식:

```
NSView 좌표 (Y=0 하단) → TV 좌표 (Y=0 상단)
  tvX = (x / viewW) × 1920
  tvY = (1 - y / viewH) × 1080
```

좌클릭 시 PC 커서를 패드 중앙으로 워프 (`CGWarpMouseCursorPosition`) → 패드 끝 도달 문제 해소.

---

## 6. 상태 관리

### ConnectionState

```swift
enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected(session: String)   // HDCP session token
    case error(String)
}
```

세션 만료 감지: `sendKeyCode()` 에서 모든 엔드포인트 실패 시 → `.disconnected` → 자동 재연결.

### 저장 형식 (JSON)

```
~/Library/Application Support/LG NetCast Remote/lg_remote_state.json

{
  "tvIP": "192.168.1.100",
  "pin": "ABCDEF",
  "savedAt": "2026-05-25 12:00:00"
}
```

---

## 7. 메뉴바 레이아웃 (v1.6 고정)

퀵버튼 영역과 연결 버튼이 **동일 위치**를 점유 → 연결 상태 변경 시 "리모컨 열기" 위치 불변.

```
연결됨:  [상태] → [퀵버튼(VOL/CH)] → [리모컨 열기] → [자동시작] → [종료]
미연결:  [상태] → [연결 버튼]      → [리모컨 열기] → [자동시작] → [종료]
```

---

## 8. 빌드 시스템

```bash
# build.sh 주요 동작
swift build -c release
# → .build/release/LGNetCastRemote 바이너리 생성
# → LGNetCastRemote.app 번들 구성 (Info.plist, 아이콘, 바이너리)
# → backup.sh 자동 실행 (ZIP)
```

App Sandbox 비활성 이유: raw BSD 소켓 (SSDP 멀티캐스트, UDP 브로드캐스트) 사용.

---

## 9. 키 코드 참조 (주요)

| 키 | 코드 |
|---|---|
| CH+/CH- | 0 / 1 |
| VOL+/VOL- | 2 / 3 |
| POWER | 8 |
| MUTE | 9 |
| 0~9 | 16~25 |
| UP/DOWN/LEFT/RIGHT | 64/65/7/6 |
| OK | 68 |
| MENU | 67 |
| RED/GREEN/YELLOW/BLUE | 114/113/99/97 |
| PLAY/STOP/PAUSE | 176/177/186 |
| FF/REW | 142/143 |

전체 목록: [`KeyMap.swift`](Sources/LGNetCastRemote/KeyMap.swift)

---

월평동 이상목 작품
