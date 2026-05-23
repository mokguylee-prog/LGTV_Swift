# Memory Index — LGTV_Swift Project

- [build.sh codesign 누락](project_build_codesign.md) — **진짜 원인**: build.sh에 codesign 없으면 .app에서 로컬 네트워크 TCC 권한 차단 → TV/프린터 검색 전혀 안 됨. swift run은 되는데 .app이 안 되면 즉시 확인.
- [MainActor portLog Heisenbug (오진)](project_mainactor_portlog_bug.md) — 코드 분석 중 발견한 별도 타이밍 이슈 (print문 있으면 동작). 진짜 원인은 codesign 누락이었음.
