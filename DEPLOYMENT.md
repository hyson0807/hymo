# 하이모(Hymo) 배포 가이드

> ⚠️ 이 앱을 수정/배포할 때마다 `hyson_kr`(웹사이트)에도 반영해야 사용자에게 나간다.

## 구조

- **개발/빌드:** `/Users/hyson/hyson_works/PROJECTS/hymo` (SwiftUI macOS 앱)
- **배포:** `/Users/hyson/hyson_works/hyson_kr` (Next.js, https://hyson.kr) — **Sparkle** 자동 업데이트
- 배포 산출물 위치: `hyson_kr/public/downloads/`
  | 파일 | 용도 |
  |------|------|
  | `hymo_app.dmg` | 신규 사용자 다운로드용 설치 파일 |
  | `hymo_update.zip` | Sparkle 업데이트용 앱 번들(zip) |
  | `appcast.xml` | Sparkle 피드 (버전 / 용량 / EdDSA 서명) — **항상 1개 item만** 두고 최신으로 갱신 |

---

## 릴리스 흐름 (2단계)

**사람(Xcode)이 공증까지 → 스크립트가 나머지 배포.** 스크립트는 앱을 다시 빌드/서명하지 않는다(공증 유지).

### 1단계 — Xcode에서 버전 올리고 공증 Export (사람)

1. 작업 시작 전 `git fetch && git merge origin/main` (머지는 항상 직접).
2. Xcode에서 **버전 올리기**: target의 `MARKETING_VERSION`(예: 1.9)과 `CURRENT_PROJECT_VERSION`
   (= Sparkle build 번호)을 **라이브보다 높게**. 라이브 확인:
   `curl -s https://hyson.kr/downloads/appcast.xml | grep sparkle:version`
3. **Product ▸ Archive**.
4. Organizer ▸ **Distribute App ▸ Direct Distribution** → Apple이 자동 **공증 + 스테이플**.
   - Developer ID 인증서 없다고 하면 Xcode가 자동 생성 제안 → 허용. (서명: `Developer ID Application: Hyson Works`)
5. 공증 완료 후 **Export** → `hymo.app` 폴더로 내보냄. 그 경로를 2단계에 넘긴다.

### 2단계 — 스크립트로 배포 (한 줄)

```sh
cd /Users/hyson/hyson_works/PROJECTS/hymo
./release.sh /경로/hymo.app        # 1단계에서 Export 한 공증본 경로
```

`release.sh`가 자동으로:
- 앱 **검증**(공증 스테이플 / 비샌드박스 / 버전 읽기) — 공증 안 됐으면 **중단**
- 라이브 build와 비교(낮으면 중단, 같으면 확인) — 버전은 `.app`에서 읽으므로 인자 불필요
- **소스 버전 동기화**: `pbxproj`를 앱 버전과 맞추고, 다르면 커밋 (저장소-라이브 어긋남 방지)
- `hymo_update.zip` + `hymo_app.dmg` 생성 (**재서명 안 함 → 공증 유지**)
- Sparkle `sign_update`로 EdDSA 서명 → `appcast.xml` 갱신(`minimumSystemVersion 14.0`)
- `hyson_kr/public/downloads/`로 복사 + length 검증
- 커밋 → **(y/n 확인 후) push** → 라이브 반영 확인

---

## ⛔ 매번 사고 났던 지점 (먼저 읽기)

1. **`origin/main` 먼저 머지하고 작업/배포한다.** 과거에 머지를 빼먹고 갈라져 Sparkle 통합·버전이 누락된 채
   작업한 적 있다. 작업 시작 전 `git fetch && git merge origin/main`.
2. **버전은 라이브보다 높게.** 저장소 버전이 아니라 실제 배포본(`appcast`의 `sparkle:version`) 기준.
   스크립트가 검사하지만, 1단계에서 Xcode 버전을 올릴 때부터 신경 쓸 것. (버전 커밋은 스크립트가 동기화해 줌)
3. **App Sandbox는 꺼진 상태 유지.** Server 탭 `lsof`/`kill`에 필요. `hymo/hymo.entitlements`의
   `com.apple.security.app-sandbox` = `<false/>`. 스크립트가 빌드 검증에서 막아준다. 하드닝 런타임은 ON.
4. **배포 타깃 = macOS 14.0.** Xcode 기본값이 15.7로 박히면 낮은 맥에서 "이 버전의 macOS에서 사용할 수 없음"
   으로 막힌다. `MACOSX_DEPLOYMENT_TARGET = 14.0` 유지(@Observable/SettingsLink 때문에 14가 하한).
   appcast `minimumSystemVersion`도 14.0(`release.sh`의 `MIN_MACOS`).
5. **공증은 Xcode Direct Distribution으로 한다.** 이게 빠지면 다른 맥에서 "확인되지 않은 개발자/악성코드 확인 불가"
   경고로 막힌다. 스크립트는 공증 안 된 앱을 받으면 중단한다.

---

## 사전 준비물 (이미 갖춰져 있음)

- **Developer ID Application 인증서**: `Hyson Works (KX7984KBJW)`. Xcode Direct Distribution이 사용/생성.
- **공증 자격**: Xcode가 로그인된 Apple 계정으로 자동 처리(별도 `notarytool` 설정 불필요).
- **Sparkle EdDSA 개인키**: 로그인 keychain의 `"Private key for signing Sparkle updates"`.
  공개키(`SUPublicEDKey`, `5ptl+MhlpmiZeoX2aVmhWUuxGMtGTfIi2Nv7tBXe+BM=`)는 `hymo/Info.plist`에 박혀 있다.
- **`sign_update` 도구**: Sparkle SPM에 포함(빌드된 적 있으면 생김). 스크립트가 자동 탐색:
  `find /tmp/hymo_spm ~/Library/Developer/Xcode/DerivedData -name sign_update -path '*Sparkle*'`

---

## 수동 배포 (스크립트가 막힐 때 참고)

> `release.sh`가 그대로 실행하는 2단계 절차. 공증본 `hymo.app`을 이미 Export 했다고 가정.

```sh
set -e
HYMO=/Users/hyson/hyson_works/PROJECTS/hymo
KR=/Users/hyson/hyson_works/hyson_kr
DL=$KR/public/downloads
APP=/경로/hymo.app          # Xcode Direct Distribution Export 결과

# 0) 검증
xcrun stapler validate "$APP"            # 공증 스테이플 (실패 시 중단)
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist"  # 버전
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP/Contents/Info.plist"             # build
codesign -d --entitlements - --xml "$APP" 2>/dev/null | \
  python3 -c "import sys,plistlib;print('sandbox=',plistlib.loads(sys.stdin.buffer.read()).get('com.apple.security.app-sandbox'))"  # False 여야

# 1) 라이브보다 높은지 확인
curl -s https://hyson.kr/downloads/appcast.xml | grep sparkle:version

# 2) 소스 버전을 앱과 맞추고 커밋(누락 방지)
cd $HYMO
sed -i '' "s/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = <앱버전>;/g; \
           s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = <앱build>;/g" hymo.xcodeproj/project.pbxproj
git add hymo.xcodeproj/project.pbxproj && git commit -m "버전 <앱버전> (build <앱build>)" || true

# 3) zip + dmg (재서명 금지 → 공증 유지)
OUT=/tmp/hymo_release_out; rm -rf "$OUT"; mkdir -p "$OUT"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT/hymo_update.zip"
STAGE=/tmp/hymo_dmg_stage; rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"; ln -s /Applications "$STAGE/Applications"
hdiutil create -volname Hymo -srcfolder "$STAGE" -ov -format UDZO "$OUT/hymo_app.dmg"

# 4) Sparkle 서명 → edSignature, length
SIGN=$(find /tmp/hymo_spm ~/Library/Developer/Xcode/DerivedData -name sign_update -path '*Sparkle*' 2>/dev/null | head -1)
"$SIGN" "$OUT/hymo_update.zip"

# 5) appcast.xml 갱신: sparkle:version/shortVersionString/pubDate/enclosure(length,edSignature)
#    minimumSystemVersion = 14.0, item 1개만 유지. pubDate:  date "+%a, %d %b %Y %H:%M:%S %z"

# 6) 복사 + 검증 + 커밋 & push
cp "$OUT/hymo_update.zip" "$DL/"; cp "$OUT/hymo_app.dmg" "$DL/"
stat -f%z "$DL/hymo_update.zip"; grep -o 'length="[0-9]*"' "$DL/appcast.xml"   # 일치해야
cd $HYMO && git push origin main          # 소스 버전 커밋 푸시
cd $KR && git add public/downloads && git commit -m "하이모 <앱버전> 배포 (공증본)" && git push origin main

# 7) 라이브 확인
curl -sI "https://hyson.kr/downloads/hymo_update.zip?t=$(date +%s)" | grep -i content-length
```

---

## 참고

- **`hyson_kr` 원격 이전됨**: `hyson_kr_client` → `hyson_kr`. 정리:
  `git -C /Users/hyson/hyson_works/hyson_kr remote set-url origin https://github.com/hyson0807/hyson_kr.git`
- **같은 버전 재배포**: 공증본 교체 등 build 번호가 라이브와 같아도 스크립트가 확인 후 진행한다. 단 Sparkle은
  같은 build 번호엔 자동 업데이트를 안 띄우므로, 이미 그 버전을 깐 사용자는 재다운로드/수동 설치해야 갱신된다.
- **자동 업데이트 동작**: Sparkle은 조용히 강제 설치하지 않는다. 사용자가 설정의 "Automatically Check for
  Updates"를 켰으면 백그라운드 주기 체크(기본 ~1일) 후 업데이트 팝업이 뜨고, 아니면 설정의
  "Check for Updates…" 버튼으로 즉시 확인. 설치는 항상 사용자 클릭.
- **커밋하지 않는 것**: `hymo_app.app/`, `*.dmg`, `*.zip`, `.DS_Store`, `xcuserdata/` 는 빌드 산출물/잡파일이라
  `.gitignore` 로 제외. (배포본 dmg/zip은 `hyson_kr` 쪽 `public/downloads/`에만 둔다.)
