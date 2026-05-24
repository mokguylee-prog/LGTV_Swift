# LG NetCast Remote

**macOS 메뉴바에서 레거시 LG NetCast TV를 제어하는 네이티브 Swift 앱**

> 대상 기기: LG NetCast TV (2014년 이전 모델 · 42LW5700 등)  
> 포트 8080 HDCP API 사용 · App Sandbox **비활성** 필요

---

## 스크린샷

![메뉴바](image/MenuBar.png) ![리모컨](image/Remocon.png)

---

## 요구사항

| 항목 | 버전 |
|---|---|
| macOS | 13 Ventura 이상 |
| Swift | 5.9 이상 |
| Xcode / Swift toolchain | 필요 |

---

## 빌드 및 실행

```bash
# 릴리스 빌드 → .app 번들 생성
./build.sh

# 빌드 후 바로 실행
./run.sh

# 개발용 (SPM debug)
swift run

# Xcode에서 열기
open Package.swift
```

빌드 산출물:

| 파일 | 설명 |
|---|---|
| `LGNetCastRemote.app` | 실행 가능한 앱 번들 |
| `LGNetCastRemote` | 단독 바이너리 (참고용) |
| `../LGNetCastRemote_YYYYMMDD_.zip` | 자동 백업 ZIP |

---

## 사용 방법

1. 앱 실행 → 메뉴바에 LG 아이콘 표시
2. 저장된 IP·PIN이 있으면 **자동 연결**
3. 미연결 시 메뉴바 팝업의 **연결** 버튼 → PIN 입력 후 연결
4. **리모컨 열기** → 전체 리모컨 패널 (리모컨 / 휠 / 패드 3가지 모드)
5. **TV 검색** → 연결 설정 창에서 네트워크 자동 탐색
6. 이후 실행 시 저장된 IP·PIN으로 자동 연결

---

## 메뉴바 팝업

### 연결 상태별 레이아웃

```
┌─────────────────────────┐
│ ● 상태 메시지            │
├─────────────────────────┤
│ [🔇] [🔉] [🔊] | [CH∧] [CH∨]  ← 연결됨
│ 또는  [연결] 버튼         ← 미연결  (항상 같은 자리)
├─────────────────────────┤
│ 리모컨 열기              ← 항상 고정 위치
├─────────────────────────┤
│ ⬛ 로그인 시 자동 시작    │
├─────────────────────────┤
│ LG NetCast Remote  종료 │
└─────────────────────────┘
```

| 퀵버튼 | 기능 | 꾹 누르기 |
|---|---|---|
| 🔇 | 음소거 | — |
| 🔉 🔊 | 볼륨 -/+ | ✓ 연속 |
| CH ∧ / CH ∨ | 채널 업/다운 | ✓ 연속 |

---

## 리모컨 모드

### 리모컨 탭
WPF RemoteWindow.xaml 디자인을 그대로 재현한 리모컨 스킨.  
전원·음소거·숫자패드·방향키·색상버튼·미디어 컨트롤 등 전체 키 포함.

### 휠 탭 (V1 / V2)
- **V1 트림 휠** — 드래그 + 관성 스크롤 + 마우스 휠  
  좌측 슬라이더로 마찰 조절 (부드럽게 ↔ 뻑뻑)
- **V2 다이얼** — 원형 다이얼로 볼륨·채널 조절

### 패드 탭
- 절대좌표 맵핑 마우스 트래킹 (TV 해상도 1920×1080 기준)
- 좌클릭 → TV 클릭 + PC 커서 패드 중앙 워프
- 우클릭 → PC 커서 워프만 (TV 클릭 없음)
- 휠 버튼 클릭 → 패드 모드 해제

---

## TV 통신 프로토콜

모든 요청: `HTTP POST` · `application/atom+xml` · `User-Agent: iPhone`

| 동작 | 엔드포인트 | 본문 |
|---|---|---|
| PIN 표시 | `/hdcp/api/auth` | `<auth><type>AuthKeyReq</type></auth>` |
| 인증 | `/hdcp/api/auth` | `<auth><type>AuthReq</type><value>PIN</value></auth>` |
| 키 입력 | `/hdcp/api/dtv_wifirc` (또는 `/command`) | `<command><session>…</session><type>HandleKeyInput</type><value>코드</value></command>` |
| 터치 이동 | `/hdcp/api/dtv_wifirc` | `<command>…<type>HandleTouchMove</type><x>dx</x><y>dy</y></command>` |
| 터치 클릭 | `/hdcp/api/dtv_wifirc` | `<command>…<type>HandleTouchClick</type></command>` |

---

## 기기 탐색 전략

`SSDPDiscovery` actor가 병렬로 실행:

1. **SSDP M-SEARCH** — UDP 멀티캐스트 `239.255.255.250:1900`
2. **B-SEARCH** — UDP 브로드캐스트 `255.255.255.255:1990`
3. **포트 스캔** — 활성 인터페이스 전체 `/24` 서브넷 TCP 8080 (동시 50개)

각 후보를 UPnP XML → 루트 페이지 헤더 → HDCP API 순으로 LG TV 여부 검증.

---

## 파일 구조

```
Sources/LGNetCastRemote/
│
├── App
│   ├── LGNetCastApp.swift              # @main · MenuBarExtra · AppDelegate
│   ├── Color+Hex.swift                 # Color(hex:) 공유 이니셜라이저
│   └── KeyMap.swift                    # LGKey enum (키 코드 매핑)
│
├── Model
│   ├── TVState.swift                   # ConnectionState · TVDevice · TVState
│   └── StateManager.swift             # JSON 설정 저장/불러오기
│
├── Controller
│   ├── TVController.swift              # @MainActor ObservableObject · 핵심 상태
│   ├── TVController+Auth.swift         # requestPIN / connect
│   ├── TVController+Keys.swift         # sendKey / sendKeyCode / sendLegacyTouch
│   ├── TVController+Mouse.swift        # 터치패드 이동·클릭·휠
│   ├── TVController+Discovery.swift    # discover / buildDevices / orderDevices
│   └── TVController+Verify.swift       # verifyLGTV / 기기 분류
│
├── Discovery
│   ├── SSDPDiscovery.swift             # actor · M-SEARCH · B-SEARCH
│   ├── SSDPDiscovery+PortScan.swift    # 포트 스캔 · checkPort
│   └── SSDPDiscovery+Helpers.swift     # UDP 전송 · 응답 파싱 · fd_set 헬퍼
│
├── UI – MenuBar
│   └── MenuBarView.swift               # 메뉴바 팝업 · 퀵버튼 · 자동시작 토글
│
├── UI – Remote
│   ├── RemoteView.swift                # 최상위 리모컨 뷰 · 모드 전환
│   ├── RemoteView+Palette.swift        # Color 팔레트 · K 키코드 · 레이아웃 상수
│   ├── RemoteView+Buttons.swift        # SkinBtn · CircleBtn · RemoteModeButton
│   ├── RemoteView+LeftSection.swift    # 좌측 패널 (숫자패드 · VOL/CH)
│   └── RemoteView+RightSection.swift   # 우측 패널 (방향키 · 색상 · 미디어)
│
├── UI – Wheel
│   ├── WheelView.swift                 # 버전 선택 컨테이너
│   ├── WheelView+FrictionSlider.swift  # 마찰 슬라이더
│   ├── WheelView+CylinderWheel.swift   # V1 트림 휠 + 관성 + 본체 렌더링
│   ├── WheelView+DialWheel.swift       # V2 원형 다이얼
│   └── WheelView+ScrollCatcher.swift   # NSView 스크롤 휠 브리지
│
├── UI – Mouse Pad
│   ├── MouseRemoteView.swift           # 패드 배경 · 이벤트 라우팅
│   └── MouseTrackingPad.swift          # NSView 절대좌표 맵핑 · 커서 워프
│
└── UI – Connection
    ├── ConnectionWindowView.swift              # IP 입력 · 기기 목록 · PIN 패널
    ├── ConnectionWindowView+ScanProgress.swift # 스캔 진행 표시 · IP 로그
    └── ConnectionWindowView+DeviceRow.swift    # DeviceRow · SummaryBadge · ScanStepRow
```

---

## 설정 저장

```
~/Library/Application Support/LG NetCast Remote/lg_remote_state.json
```

## 로그인 자동 시작

```
~/Library/LaunchAgents/com.kadelee.lgnetcast.menubar.plist
```

---

## 변경 이력

| 버전 | 주요 변경 |
|---|---|
| **v1.6** | 소스 파일 분해 (12→30개, ~5KB/파일) · 메뉴바 레이아웃 고정 (연결↔퀵버튼 자리 교환) |
| v1.5 | 터치패드 절대맵핑 · 트림휠 리얼 스타일 + 관성 · 다이얼 V2 추가 |
| v1.3 | 코드사인 · 앱 번들 배포 |
| v1.0 | 최초 Swift 포팅 (Python/Tkinter/rumps → SwiftUI) |

---

월평동 이상목 작품
