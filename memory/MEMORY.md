# Memory Index — LGTV_Swift Project

- [build.sh codesign 누락](project_build_codesign.md) — **진짜 원인**: build.sh에 codesign 없으면 .app에서 로컬 네트워크 TCC 권한 차단 → TV/프린터 검색 전혀 안 됨. swift run은 되는데 .app이 안 되면 즉시 확인.
- [MainActor Heisenbug + 검색 속도 튜닝](project_mainactor_portlog_bug.md) — verifyLGTV를 nonisolated로 전환해 병렬 검증 수정. 검색 속도는 SSDP 2s / 포트스캔 300ms / 동시100 / 검증포트 1200ms로 튜닝 완료 (2026-05-23 확인).
