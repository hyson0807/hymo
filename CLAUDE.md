# 하이모 (Hymo) — SwiftUI macOS 메모 앱

## ⚠️ 배포 주의 (반드시 기억)

이 앱을 수정/업데이트하면 **반드시 `hyson_kr` 프로젝트에도 반영**해야 한다.
- 배포처: `/Users/hyson/hyson_works/hyson_kr` (Next.js, https://hyson.kr) — Sparkle 자동 업데이트.
- 갱신 대상: `hyson_kr/public/downloads/` 의 `hymo_app.dmg`, `hymo_update.zip`, `appcast.xml`.
- 자세한 절차는 [DEPLOYMENT.md](./DEPLOYMENT.md) 참고.

## 커밋하지 않는 것

`*.app/`, `*.dmg`, `*.zip`, `.DS_Store`, `xcuserdata/` 는 빌드 산출물 → `.gitignore` 제외. 소스만 커밋.
