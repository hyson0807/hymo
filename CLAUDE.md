# 하이모 (Hymo) — SwiftUI macOS 메모 앱

## ⚠️ 배포 주의 (반드시 기억)

이 앱을 수정/업데이트하면 **반드시 `hyson_kr` 프로젝트에도 반영**해야 한다.
- 배포처: `/Users/hyson/hyson_works/hyson_kr` (Next.js, https://hyson.kr) — Sparkle 자동 업데이트.
- 갱신 대상: `hyson_kr/public/downloads/` 의 `hymo_app.dmg`, `hymo_update.zip`, `appcast.xml`.
- **릴리스 전 필수 3가지** (자세한 CLI 런북은 [DEPLOYMENT.md](./DEPLOYMENT.md)):
  1. 작업 전 `git merge origin/main` (과거 머지 빼먹고 갈라진 적 있음).
  2. 버전 범프(`MARKETING_VERSION`+`CURRENT_PROJECT_VERSION`)는 **커밋·push 까지** 한다(과거 1.5/1.6 누락).
  3. 새 버전은 **라이브 appcast(`curl https://hyson.kr/downloads/appcast.xml`)보다 높게**. 저장소 버전 기준 아님.
- App Sandbox는 **off 유지**(`hymo.entitlements` app-sandbox=`false`) — Server 탭 lsof/kill에 필요. 공증은 현재 생략.

## 커밋하지 않는 것

`*.app/`, `*.dmg`, `*.zip`, `.DS_Store`, `xcuserdata/` 는 빌드 산출물 → `.gitignore` 제외. 소스만 커밋.
