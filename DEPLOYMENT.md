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

## ⛔ 매번 사고 났던 지점 (먼저 읽기)

1. **`origin/main` 먼저 머지하고 작업/배포한다.** 과거에 머지를 빼먹고 갈라져서, 로컬에 Sparkle 통합·버전이
   누락된 채 작업한 적이 있다. 작업 시작 전 `git fetch && git merge origin/main`.
2. **버전 올리면 그 커밋을 반드시 push 한다.** 과거 1.5·1.6은 Xcode에서 아카이브만 하고
   `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` 범프를 git에 커밋하지 않아, 저장소(1.4)와 라이브(1.6)가
   어긋났다. 버전 범프 = 커밋 = push 까지 한 세트.
3. **새 버전은 반드시 "라이브 appcast"보다 높여야 한다.** 저장소 버전이 아니라 실제 배포본 기준.
   배포 전 `curl -s https://hyson.kr/downloads/appcast.xml | grep sparkle:version` 로 현재 라이브 build 번호를 확인하고 +1.
4. **App Sandbox는 꺼진 상태를 유지한다.** Server 탭의 `lsof`/`kill`에 필요. `hymo/hymo.entitlements`의
   `com.apple.security.app-sandbox` 가 `<false/>` 여야 한다(빌드 후 검증 단계 참고). 하드닝 런타임은 ON 유지.
5. **공증(notarization)은 현재 안 한다.** 기존 릴리스도 미공증(서명만). 새로 받는 사용자는 Gatekeeper 경고가
   날 수 있음 — 바꾸려면 Developer ID 인증서 + `notarytool` 세팅 필요(현재 둘 다 없음).

---

## 사전 준비물 (이미 갖춰져 있음)

- **Sparkle EdDSA 개인키**: 로그인 keychain의 `"Private key for signing Sparkle updates"` 항목.
  공개키(`SUPublicEDKey`, `5ptl+MhlpmiZeoX2aVmhWUuxGMtGTfIi2Nv7tBXe+BM=`)는 `hymo/Info.plist`에 박혀 있다.
- **서명 인증서**: `Apple Development: hyunsung sim` (팀 `KX7984KBJW`). 기존 배포와 동일하게 이걸로 자동 서명.
- **`sign_update` 도구**: Sparkle SPM에 포함. 빌드 후 아래 경로에 생긴다(없으면 `find` 로 찾기):
  ```sh
  find ~/Library/Developer/Xcode/DerivedData /tmp -name sign_update -path '*Sparkle*' 2>/dev/null | head -1
  ```

---

## 릴리스 런북 (CLI, 복붙용)

> 아래는 1.7(8) 릴리스 때 실제로 쓴 절차. `NEW_SHORT`/`NEW_BUILD`만 바꿔 그대로 반복하면 된다.
> (Xcode Organizer의 Archive→Distribute 없이 CLI로 전부 가능.)

```sh
set -e
HYMO=/Users/hyson/hyson_works/PROJECTS/hymo
KR=/Users/hyson/hyson_works/hyson_kr
DL=$KR/public/downloads

# 0) 라이브 버전 확인 → 새 버전은 이보다 높게
curl -s https://hyson.kr/downloads/appcast.xml | grep -E 'sparkle:version|shortVersionString'
NEW_SHORT=1.7     # ← 라이브보다 높게
NEW_BUILD=8       # ← sparkle:version. 라이브 build +1

cd $HYMO
git fetch origin && git merge origin/main   # 1) 항상 머지 먼저

# 2) 버전 범프 (Debug+Release 둘 다)
sed -i '' "s/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = $NEW_SHORT;/g; \
           s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = $NEW_BUILD;/g" \
           hymo.xcodeproj/project.pbxproj

# 3) Release 빌드
rm -rf /tmp/hymo_rel
xcodebuild -scheme hymo -configuration Release \
  -derivedDataPath /tmp/hymo_rel -clonedSourcePackagesDirPath /tmp/hymo_spm build
APP=/tmp/hymo_rel/Build/Products/Release/hymo.app

# 3-1) 검증: 버전 / 비샌드박스 / 서명 / Sparkle 임베드
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist"
codesign -d --entitlements - --xml "$APP" 2>/dev/null | \
  python3 -c "import sys,plistlib;print('sandbox=',plistlib.loads(sys.stdin.buffer.read()).get('com.apple.security.app-sandbox'))"
# sandbox= False 여야 함

# 4) 업데이트 zip + dmg 생성
OUT=/tmp/hymo_release_out; rm -rf "$OUT"; mkdir -p "$OUT"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT/hymo_update.zip"
STAGE=/tmp/hymo_dmg_stage; rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"; ln -s /Applications "$STAGE/Applications"
hdiutil create -volname Hymo -srcfolder "$STAGE" -ov -format UDZO "$OUT/hymo_app.dmg"

# 5) Sparkle EdDSA 서명 (키체인 키 자동 사용) → edSignature, length 출력
SIGN=$(find ~/Library/Developer/Xcode/DerivedData /tmp -name sign_update -path '*Sparkle*' 2>/dev/null | head -1)
"$SIGN" "$OUT/hymo_update.zip"
# 출력된 sparkle:edSignature="..." length="..." 를 appcast에 반영

# 6) appcast.xml 갱신: title/sparkle:version/shortVersionString/pubDate/enclosure(length,edSignature)
#    pubDate 포맷:  date "+%a, %d %b %Y %H:%M:%S %z"
#    item 은 1개만 유지(최신으로 덮어쓰기). 릴리스 노트는 <description><![CDATA[ ... ]]> 에.

# 7) 산출물 복사
cp "$OUT/hymo_update.zip" "$DL/"; cp "$OUT/hymo_app.dmg" "$DL/"

# 8) 검증: appcast length == 실제 zip 크기
stat -f%z "$DL/hymo_update.zip"; grep -o 'length="[0-9]*"' "$DL/appcast.xml"

# 9) 커밋 & push (둘 다!)
cd $HYMO && git add -A && git commit -m "버전 $NEW_SHORT (build $NEW_BUILD) 릴리스" && git push origin main
cd $KR && git add public/downloads && git commit -m "하이모 $NEW_SHORT 배포" && git push origin main

# 10) 라이브 반영 확인 (사이트 자동배포 1~3분 소요)
curl -s "https://hyson.kr/downloads/appcast.xml?t=$(date +%s)" | grep sparkle:version
```

---

## 참고

- **`hyson_kr` 원격 이전됨**: `hyson_kr_client` → `hyson_kr`. 정리:
  `git -C /Users/hyson/hyson_works/hyson_kr remote set-url origin https://github.com/hyson0807/hyson_kr.git`
- **자동 업데이트 동작**: Sparkle은 조용히 강제 설치하지 않는다. 사용자가 설정의 "Automatically Check for
  Updates"를 켰으면 백그라운드 주기 체크(기본 ~1일) 후 업데이트 팝업이 뜨고, 아니면 설정의
  "Check for Updates…" 버튼으로 즉시 확인. 설치는 항상 사용자 클릭. (더 적극적으로 하려면 `Info.plist`에
  `SUEnableAutomaticChecks=true`, `SUScheduledCheckInterval` 추가 검토.)
- **커밋하지 않는 것**: `hymo_app.app/`, `*.dmg`, `*.zip`, `.DS_Store`, `xcuserdata/` 는 빌드 산출물/잡파일이라
  `.gitignore` 로 제외. (배포본 dmg/zip은 `hyson_kr` 쪽 `public/downloads/`에만 둔다.)
