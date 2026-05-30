# 하이모(Hymo) 배포 가이드

> ⚠️ **중요: 이 앱을 수정/업데이트하면 반드시 `hyson_kr` 프로젝트에도 반영해야 한다.**

## 구조

- **개발/빌드:** `/Users/hyson/hyson_works/PROJECTS/hymo` (이 프로젝트, SwiftUI macOS 앱)
- **배포:** `/Users/hyson/hyson_works/hyson_kr` (Next.js 웹사이트, https://hyson.kr)
  - 사용자는 hyson.kr 에서 앱을 다운로드하고, **Sparkle** 자동 업데이트로 새 버전을 받는다.

## 배포 산출물 위치 (`hyson_kr/public/downloads/`)

| 파일 | 용도 |
|------|------|
| `hymo_app.dmg` | 신규 사용자 다운로드용 설치 파일 |
| `hymo_update.zip` | Sparkle 자동 업데이트용 앱 번들(zip) |
| `appcast.xml` | Sparkle 업데이트 피드 (버전 / 용량 / EdDSA 서명) |

## 앱 업데이트 시 체크리스트

1. **이 프로젝트에서 코드 수정** 후 Xcode에서 버전 올리기
   - `MARKETING_VERSION`(예: 1.6) 과 `CURRENT_PROJECT_VERSION`(`sparkle:version`, 예: 7) 둘 다 올린다.
2. 앱 빌드 → `.app` / `.dmg` 생성
3. **Sparkle 업데이트 zip 생성** 후 EdDSA 서명 (Sparkle의 `sign_update` 도구)
4. `hyson_kr/public/downloads/` 에 복사/갱신:
   - `hymo_app.dmg` 교체
   - `hymo_update.zip` 교체
   - `appcast.xml` 의 `sparkle:version`, `sparkle:shortVersionString`, `enclosure length`(zip 바이트 수), `sparkle:edSignature`, `pubDate` 갱신
5. `hyson_kr` 사이트 배포 (커밋/푸시 → 호스팅 반영)

## 참고: 이 레포에 커밋하지 않는 것

`hymo_app.app/`, `*.dmg`, `*.zip`, `.DS_Store`, `xcuserdata/` 는 빌드 산출물/잡파일이라 `.gitignore` 로 제외됨. 소스코드만 커밋한다.
