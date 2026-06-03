# 하이모 (Hymo) — SwiftUI macOS 메모 앱

## ⚠️ 배포 주의 (반드시 기억)

이 앱을 수정/업데이트하면 **반드시 `hyson_kr` 프로젝트에도 반영**해야 한다.
- 배포처: `/Users/hyson/hyson_works/hyson_kr` (Next.js, https://hyson.kr) — Sparkle 자동 업데이트.
- 갱신 대상: `hyson_kr/public/downloads/` 의 `hymo_app.dmg`, `hymo_update.zip`, `appcast.xml`.
- **릴리스 흐름** (자세한 건 [DEPLOYMENT.md](./DEPLOYMENT.md)): ① Xcode에서 버전 올리고 Archive →
  Distribute App ▸ **Direct Distribution(자동 공증)** ▸ Export → ② `./release.sh /경로/hymo.app`
  (스크립트가 검증·zip/dmg·Sparkle 서명·appcast·hyson_kr 배포까지). 스크립트는 **재빌드/재서명 안 함**(공증 유지).
- **릴리스 전 필수**:
  1. 작업 전 `git merge origin/main` (과거 머지 빼먹고 갈라진 적 있음).
  2. 새 버전은 **라이브 appcast(`curl https://hyson.kr/downloads/appcast.xml`)보다 높게**. 저장소 버전 기준 아님.
     (버전 커밋 동기화는 release.sh가 해 줌 — 과거 1.5/1.6 누락 방지.)
- App Sandbox는 **off 유지**(`hymo.entitlements` app-sandbox=`false`) — Server 탭 lsof/kill에 필요.
- 배포 타깃 **macOS 14.0** 유지(15.7로 박히면 낮은 맥에서 실행 막힘). 공증은 **함**(Developer ID, Xcode Direct Distribution).

## 커밋하지 않는 것

`*.app/`, `*.dmg`, `*.zip`, `.DS_Store`, `xcuserdata/` 는 빌드 산출물 → `.gitignore` 제외. 소스만 커밋.
