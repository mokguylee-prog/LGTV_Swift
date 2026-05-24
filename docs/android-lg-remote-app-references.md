# Android LG Remote App References

작성일: 2026-05-24

이 문서는 LGTV_Swift의 `리모컨`, `휠`, `마우스` 화면을 설계할 때 참고할 Android LG TV Remote 앱 자료를 모아둔 것이다. 원본 이미지 파일은 저장하지 않고, 저작권과 출처 확인을 위해 원본 페이지 및 이미지 링크를 문서에 남긴다.

## 핵심 확인

- LG 공식 NetCast 개발 문서에는 `LG TV Remote 2011` 및 `LG TV Remote` 스마트폰 앱이 Android/iOS에서 동작한다고 안내되어 있다.
- Android LG 리모컨 앱들은 보통 일반 리모컨 화면과 별도로 `Touchpad`, `Mouse Pointer`, `Keyboard`, `App Launcher`, `Channel/Volume` 화면을 분리한다.
- 2011 NetCast 계열 레퍼런스에는 포인터를 움직이는 터치패드 화면이 실제로 존재한다. 현재 앱의 `마우스` 탭도 별도 패널로 유지하는 방향이 맞다.
- `휠` 화면은 물리 LG Magic Remote의 wheel/OK 개념과 Android 앱의 channel/volume dial 패턴을 섞어, 볼륨 휠과 채널 휠을 별도 컨트롤로 두는 방향이 자연스럽다.

## 공식/기술 근거

### LG NetCast 개발 문서

- 출처: [LG NetCast Developing Web App PDF](https://webostv.developer.lge.com/assets/netcast/NetCast-Developing%20Web%20App.pdf)
- 확인 내용:
  - `LG TV Remote 2011` 프로그램은 LG Smart TV 2011 / NetCast 2.0에서 Android phone을 지원한다.
  - `LG TV Remote` 프로그램은 LG Smart TV 2012/2013 / NetCast 3.0/4.0에서 Android phone/pad를 지원한다.
  - TV pairing key를 스마트폰 앱에 입력하는 흐름이 공식 문서에 설명되어 있다.

## Android 앱 레퍼런스

### LG TV Remote 2011

- 출처: [Uptodown - LG TV Remote 2011](https://lg-tv-remote-2011.en.uptodown.com/android)
- 패키지: `com.clipcomm.WiFiRemocon`
- 개발사: LG Electronics
- 확인 내용:
  - 2011 LG Smart TV용 공식 앱으로 소개되어 있다.
  - 앱 설명에 터치패드로 TV 포인터를 조작하는 기능이 명시되어 있다.
  - 스크린샷에 remote, channel, touchpad/mouse pad 형태가 남아 있다.

참고 이미지:

![LG TV Remote 2011 channel screen](https://img.utdstc.com/screen/3b4/33c/3b433c52f8d789579f28f189c8121f934ed17bf64fcf1c8f7e881f995bbf0a1e)

![LG TV Remote 2011 touchpad screen 1](https://img.utdstc.com/screen/f06/45d/f0645d1f1140d3cbc59c207117c32040414a2458870ff93780c281056c51ac5d)

![LG TV Remote 2011 touchpad screen 2](https://img.utdstc.com/screen/dec/3e3/dec3e3b43a51be34b3cd261691c2dd5c953987ebff67dba31f4638fb4bbfa6d6)

### LG TV Remote Control Plus / Mouse Pointer 스타일

- 출처: [LG TV Remote App For Android](https://www.lgtvremoteapp.com/lg-tv-remote-app-android/)
- 확인 내용:
  - 화면 구성이 `remote`, `trackpad`, `keypad`, `keyboard`, `app launcher`처럼 모드별로 분리되어 있다.
  - 문서에서 Premium 기능으로 `Keyboard`, `Mouse Pointer`, `App Launcher`를 구분한다.
  - 채널 다이얼/패널형 화면이 있어 `휠` 화면 구상에 참고할 수 있다.

참고 이미지:

![LG remote app multi panel screenshots](https://www.lgtvremoteapp.com/wp-content/uploads/2023/08/three-android-phones-lg-remote-app.jpg)

![LG remote app mouse pointer tablet](https://www.mirrormeister.com/wp-content/uploads/2023/08/mouse-pointer-tablet-remote-lg.jpg)

![LG remote app channel feature](https://www.mirrormeister.com/wp-content/uploads/2023/08/channel-feature-lg-tv-remote-app.jpg)

![LG remote app keyboard](https://www.mirrormeister.com/wp-content/uploads/2023/08/keyboard-lg-tv-remote-app-android.jpg)

### Remote Control for LG TV

- 출처: [Google Play - Remote Control for LG TV](https://play.google.com/store/apps/details?id=tv.remote.control.lg)
- 확인 내용:
  - WebOS 기반 LG TV용 앱으로 소개되어 있다.
  - 기능 설명에 자동 TV 탐색, 전체 리모컨, 큰 터치패드, 전체 키보드가 포함되어 있다.
  - 현재 앱의 마우스 패널은 이 패턴처럼 큰 터치 영역을 우선하고, 클릭/스크롤은 보조 버튼으로 두는 편이 좋다.

### Smart TV Remote for LG SmartTV

- 출처: [AppRecs - Smart TV Remote for LG SmartTV](https://apprecs.com/android/wifi.control.lg/smart-tv-remote-for-lg-smarttv)
- 확인 내용:
  - Netcast 또는 WebOS LG Smart TV를 Wi-Fi로 제어한다고 설명한다.
  - keyboard, touchpad, shortcut 기능을 함께 제공한다.
  - 현재 앱의 `리모컨`, `휠`, `마우스` 탭 분리 방향과 잘 맞는다.

## 우리 앱에 반영할 방향

### 마우스 화면

- 큰 트랙패드 영역을 중심에 둔다.
- PC 마우스 이동을 캡처해 TV pointer 이동 명령으로 변환한다.
- 왼쪽 클릭, 스크롤 위/아래, 커서 표시/숨김은 명확한 보조 버튼으로 둔다.
- 마우스 모드 진입 시 cursor visible 명령을 먼저 보내고, 나갈 때 숨김 명령을 보낸다.

### 휠 화면

- 볼륨 휠과 채널 휠을 분리한다.
- 각 휠은 회전 제스처 또는 위/아래 스텝 버튼을 모두 지원할 수 있게 만든다.
- 가운데에는 `OK` 또는 mute 같은 자주 쓰는 동작을 둘 수 있다.
- 리모컨 화면의 보조 기능이 아니라 별도 모드로 유지한다.

### 검색/연결 흐름과의 관계

- Android 앱들은 대체로 `기기 검색 -> 선택 -> pairing key 입력 -> remote mode 진입` 흐름을 유지한다.
- TV가 판명되면 바로 PIN 전송 단계로 이어지는 현재 방향은 사용자 조작 수를 줄이는 면에서 맞다.
- 다만 NetCast 2011 계열은 pairing 방식과 pointer 지원 여부가 모델별로 다를 수 있으므로, 실패 시 IP별 상태 로그를 더 자세히 남기는 것이 중요하다.
