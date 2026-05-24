# AGENTS.md

이 문서는 Codex/에이전트가 이 저장소에서 작업할 때 우선 참고해야 하는 프로젝트 규칙이다.

## 프로젝트 개요

- 앱 이름: `LGNetCastRemote`
- 플랫폼: macOS 13 이상
- 언어/프레임워크: Swift 5.9, SwiftUI, AppKit 일부
- 목적: LG NetCast TV를 macOS 메뉴바 앱에서 검색, 연결, 제어한다.
- 주요 대상: 2014년 이전 LG NetCast TV, 특히 HDCP API 포트 `8080` 기반 모델

## 작업 원칙

- 사용자가 명시적으로 요청한 범위만 수정한다.
- 기존 변경분이 있으면 되돌리지 말고, 먼저 상태를 확인한 뒤 필요한 부분만 건드린다.
- 기능 수정 전에는 관련 파일을 먼저 읽고 기존 구조에 맞춘다.
- 큰 구조 변경, 프로토콜 변경, GitHub push, 버전 변경은 사용자 허락을 받은 뒤 진행한다.
- 사용자가 "원래대로", "허락 받고 수정" 같은 말을 한 이력이 있으므로, 애매한 수정은 먼저 확인한다.

## 빌드/실행

사용자가 지정한 빌드 방식은 `build.sh`이다.

```bash
./build.sh release
```

또는 디버그 빌드:

```bash
./build.sh debug
```

주의:

- `build.sh`는 Swift 빌드, `.app` 번들 생성, ad-hoc codesign, 백업, 앱 실행까지 수행한다.
- 단순히 `swift build`만 성공해도 실제 앱 번들 실행 결과와 다를 수 있다.
- 앱 실행 확인이 필요하면 기존 실행 중인 앱이 이전 버전인지도 함께 확인한다.

## 주요 파일

- `Sources/LGNetCastRemote/LGNetCastApp.swift`: 앱 진입점, 메뉴바, AppDelegate
- `Sources/LGNetCastRemote/TVController.swift`: TV 통신, 인증, 키 입력, 마우스/휠 명령
- `Sources/LGNetCastRemote/SSDPDiscovery.swift`: SSDP, B-SEARCH, 포트 스캔
- `Sources/LGNetCastRemote/ConnectionWindowView.swift`: TV 연결 설정 창
- `Sources/LGNetCastRemote/RemoteView.swift`: 리모컨 화면 및 모드 전환
- `Sources/LGNetCastRemote/MouseRemoteView.swift`: 마우스 모드 UI와 입력 캡처
- `Sources/LGNetCastRemote/KeyMap.swift`: 키 코드 매핑
- `Sources/LGNetCastRemote/TVState.swift`: 연결 상태와 TV 모델
- `Sources/LGNetCastRemote/StateManager.swift`: 설정 저장/불러오기
- `build.sh`: 공식 빌드 스크립트
- `docs/`: 조사 문서 및 레퍼런스

## LG TV 통신 메모

- 기본 HDCP API:
  - Base URL: `http://<ip>:8080/hdcp/api`
  - PIN 표시: `/hdcp/api/auth`
  - 인증: `/hdcp/api/auth`
  - 키 입력: `/hdcp/api/dtv_wifirc` 또는 `/hdcp/api/command`
- NetCast/UDAP 관련 자료는 모델별 차이가 크므로, 실제 TV 동작 확인 전에는 단정하지 않는다.
- 마우스 포인터/터치패드 기능은 모델, pairing 방식, endpoint 차이로 실패할 수 있다.
- TV 검색 문제를 볼 때는 IP별 상태 로그와 포트 `8080` 응답을 우선 확인한다.

## UI 방향

- 리모컨 화면 상단 모드는 `리모컨`, `휠`, `마우스`를 유지한다.
- `리모컨`은 기존 버튼 리모컨 역할이다.
- `휠`은 볼륨/채널 휠 컨트롤을 넣을 예정인 별도 화면이다.
- `마우스`는 PC 마우스 이동을 TV pointer/touch 명령으로 변환하는 별도 화면이다.
- 연결되지 않은 상태에서 리모컨을 열면 연결 설정으로 이어지는 흐름을 우선한다.

## 문서/레퍼런스

- Android LG Remote 앱 레퍼런스는 `docs/android-lg-remote-app-references.md`에 정리되어 있다.
- 외부 이미지는 원본 파일을 저장하기보다 출처 링크와 이미지 링크를 남긴다.

## Git/GitHub

- 사용자가 요청하지 않으면 commit, tag, push를 하지 않는다.
- 버전 업데이트는 `build.sh`의 `APP_VERSION`과 필요 시 관련 문서를 함께 확인한다.
- push 전에는 `git status --short`로 포함될 변경 파일을 사용자에게 명확히 알려준다.
