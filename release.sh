#!/bin/bash
#
# 하이모 릴리스 자동화 — 사용법:  ./release.sh <버전>     예) ./release.sh 1.8
#
#   <버전>      = 사용자에게 보이는 MARKETING_VERSION (예: 1.8)
#   빌드 번호    = 라이브 appcast의 sparkle:version + 1 로 자동 계산
#
# 하는 일: 검사 → 버전 범프 → Release 빌드 → zip/dmg → Sparkle 서명 →
#          appcast 갱신 → hyson_kr 복사 → 커밋 → (확인 후) push → 라이브 검증
# 안 하는 일: git merge (충돌 위험 → 사람이 직접). 시작 시 "안 뒤처졌는지" 검사만 한다.
#
set -euo pipefail

# ── 경로/상수 ───────────────────────────────────────────────
HYMO="/Users/hyson/hyson_works/PROJECTS/hymo"
KR="/Users/hyson/hyson_works/hyson_kr"
DL="$KR/public/downloads"
APPCAST_URL="https://hyson.kr/downloads/appcast.xml"
SCHEME="hymo"

bold() { printf "\033[1m%s\033[0m\n" "$1"; }
ok()   { printf "\033[32m✓\033[0m %s\n" "$1"; }
die()  { printf "\033[31m✗ %s\033[0m\n" "$1" >&2; exit 1; }
step() { printf "\n\033[1m▶ %s\033[0m\n" "$1"; }

# ── 0) 인자 확인 ────────────────────────────────────────────
NEW_SHORT="${1:-}"
[ -n "$NEW_SHORT" ] || die "버전을 입력하세요.  예) ./release.sh 1.8"
echo "$NEW_SHORT" | grep -qE '^[0-9]+\.[0-9]+(\.[0-9]+)?$' || die "버전 형식이 이상함: '$NEW_SHORT' (예: 1.8)"

cd "$HYMO"

# ── 1) 사전 검사: 작업트리 깨끗 + origin/main보다 안 뒤처짐 ──
step "사전 검사"
git diff-index --quiet HEAD -- || die "커밋 안 된 변경이 있음. 코드 변경을 먼저 커밋하세요."
ok "작업트리 깨끗"
git fetch -q origin
BEHIND=$(git rev-list --count HEAD..origin/main)
[ "$BEHIND" = "0" ] || die "origin/main 보다 $BEHIND 커밋 뒤처짐. 먼저 'git merge origin/main' 하세요."
ok "origin/main 과 동기화됨"

# ── 2) 라이브 버전 읽어서 새 빌드 번호 = +1 ─────────────────
step "라이브 버전 확인"
LIVE_XML=$(curl -fsS "${APPCAST_URL}?t=$(date +%s)") || die "라이브 appcast를 못 읽음: $APPCAST_URL"
LIVE_BUILD=$(echo "$LIVE_XML" | grep -oE '<sparkle:version>[0-9]+' | grep -oE '[0-9]+' | head -1)
LIVE_SHORT=$(echo "$LIVE_XML" | grep -oE '<sparkle:shortVersionString>[0-9.]+' | grep -oE '[0-9.]+' | head -1)
[ -n "$LIVE_BUILD" ] || die "라이브 sparkle:version 을 못 읽음"
NEW_BUILD=$((LIVE_BUILD + 1))
[ "$NEW_SHORT" != "$LIVE_SHORT" ] || die "새 버전($NEW_SHORT)이 라이브($LIVE_SHORT)와 같음. 더 높여야 함."
ok "라이브 ${LIVE_SHORT}(${LIVE_BUILD}) → 새 릴리스 ${NEW_SHORT}(${NEW_BUILD})"

# ── 3) 릴리스 노트 + 시작 확인 ──────────────────────────────
printf "릴리스 노트 한 줄 (엔터=생략): "
read -r NOTES || NOTES=""
echo
bold "이렇게 진행합니다:  ${NEW_SHORT} (build ${NEW_BUILD})"
printf "계속할까요? [y/N] "; read -r ANS; [ "$ANS" = "y" ] || die "취소됨"

# ── 4) 버전 범프 ────────────────────────────────────────────
step "버전 범프 → ${NEW_SHORT} (${NEW_BUILD})"
sed -i '' "s/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = ${NEW_SHORT};/g; \
           s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = ${NEW_BUILD};/g" \
           hymo.xcodeproj/project.pbxproj
ok "project.pbxproj 갱신"

# ── 5) Release 빌드 ─────────────────────────────────────────
step "Release 빌드"
rm -rf /tmp/hymo_rel
xcodebuild -scheme "$SCHEME" -configuration Release \
  -derivedDataPath /tmp/hymo_rel -clonedSourcePackagesDirPath /tmp/hymo_spm build \
  > /tmp/hymo_build.log 2>&1 || { tail -30 /tmp/hymo_build.log; die "빌드 실패 (로그: /tmp/hymo_build.log)"; }
APP="/tmp/hymo_rel/Build/Products/Release/hymo.app"
ok "빌드 성공"

# 검증: 버전 / 비샌드박스
BUILT_VER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
[ "$BUILT_VER" = "$NEW_SHORT" ] || die "빌드된 버전($BUILT_VER) != 요청($NEW_SHORT)"
SBX=$(codesign -d --entitlements - --xml "$APP" 2>/dev/null | \
      python3 -c "import sys,plistlib;print(plistlib.loads(sys.stdin.buffer.read()).get('com.apple.security.app-sandbox'))")
[ "$SBX" = "False" ] || die "App Sandbox 가 꺼져있지 않음(=$SBX). Server 탭 lsof/kill 막힘."
ok "검증: 버전 ${BUILT_VER}, 비샌드박스, 서명 OK"

# ── 6) zip + dmg ────────────────────────────────────────────
step "업데이트 zip + dmg 생성"
OUT=/tmp/hymo_release_out; rm -rf "$OUT"; mkdir -p "$OUT"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT/hymo_update.zip"
STAGE=/tmp/hymo_dmg_stage; rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"; ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Hymo" -srcfolder "$STAGE" -ov -format UDZO "$OUT/hymo_app.dmg" >/dev/null
ok "zip $(stat -f%z "$OUT/hymo_update.zip") bytes, dmg 생성"

# ── 7) Sparkle EdDSA 서명 ───────────────────────────────────
step "Sparkle 서명"
SIGN=$(find /tmp/hymo_spm ~/Library/Developer/Xcode/DerivedData -name sign_update -path '*Sparkle*' 2>/dev/null | head -1)
[ -n "$SIGN" ] || die "sign_update 도구를 못 찾음"
SIGOUT=$("$SIGN" "$OUT/hymo_update.zip")
EDSIG=$(echo "$SIGOUT" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')
LEN=$(echo "$SIGOUT"   | sed -n 's/.*length="\([0-9]*\)".*/\1/p')
[ -n "$EDSIG" ] && [ -n "$LEN" ] || die "서명 파싱 실패: $SIGOUT"
ok "서명 완료 (length=$LEN)"

# ── 8) appcast.xml 작성 (item 1개만 유지) ───────────────────
step "appcast.xml 갱신"
PUBDATE=$(date "+%a, %d %b %Y %H:%M:%S %z")
DESC=""
[ -n "$NOTES" ] && DESC="
            <description><![CDATA[<ul><li>${NOTES}</li></ul>]]></description>"
cat > "$DL/appcast.xml" <<EOF
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/" version="2.0">
    <channel>
        <title>Hymo Updates</title>
        <link>https://hyson.kr/downloads/appcast.xml</link>
        <description>Hymo app updates</description>
        <language>ko</language>
        <item>
            <title>Version ${NEW_SHORT}</title>${DESC}
            <sparkle:version>${NEW_BUILD}</sparkle:version>
            <sparkle:shortVersionString>${NEW_SHORT}</sparkle:shortVersionString>
            <pubDate>${PUBDATE}</pubDate>
            <enclosure url="https://hyson.kr/downloads/hymo_update.zip" length="${LEN}" type="application/octet-stream" sparkle:edSignature="${EDSIG}"/>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
        </item>
    </channel>
</rss>
EOF
ok "appcast 작성"

# ── 9) hyson_kr 로 복사 + 검증 ──────────────────────────────
step "산출물 복사"
cp "$OUT/hymo_update.zip" "$DL/hymo_update.zip"
cp "$OUT/hymo_app.dmg"    "$DL/hymo_app.dmg"
ZIPSIZE=$(stat -f%z "$DL/hymo_update.zip")
[ "$ZIPSIZE" = "$LEN" ] || die "zip 크기($ZIPSIZE) != appcast length($LEN)"
ok "복사 완료, length 일치($LEN)"

# ── 10) 커밋 ────────────────────────────────────────────────
step "커밋"
cd "$HYMO"
git add hymo.xcodeproj/project.pbxproj
git commit -q -m "버전 ${NEW_SHORT} (build ${NEW_BUILD}) 릴리스" && ok "hymo 커밋"
cd "$KR"
git add public/downloads/appcast.xml public/downloads/hymo_update.zip public/downloads/hymo_app.dmg
git commit -q -m "하이모 ${NEW_SHORT} (build ${NEW_BUILD}) 배포" && ok "hyson_kr 커밋"

# ── 11) push 확인 (되돌리기 어려운 라이브 배포) ─────────────
echo
bold "여기서 push 하면 전체 사용자에게 ${NEW_SHORT} 자동업데이트가 나갑니다."
printf "라이브에 배포(push)할까요? [y/N] "; read -r ANS
if [ "$ANS" != "y" ]; then
  echo "push 보류. 나중에 직접:  (cd $HYMO && git push) && (cd $KR && git push)"
  exit 0
fi

step "push"
( cd "$HYMO" && git push -q origin main ) && ok "hymo push"
( cd "$KR"   && git push -q origin main ) && ok "hyson_kr push"

# ── 12) 라이브 반영 확인 ────────────────────────────────────
step "라이브 반영 확인 (자동배포 1~3분)"
for i in $(seq 1 12); do
  V=$(curl -fsS "${APPCAST_URL}?t=$(date +%s)" 2>/dev/null | grep -oE '<sparkle:version>[0-9]+' | grep -oE '[0-9]+' | head -1 || true)
  printf "  [%s] 라이브 build=%s\n" "$i" "${V:-?}"
  [ "$V" = "$NEW_BUILD" ] && { ok "라이브 반영 완료 — ${NEW_SHORT} (${NEW_BUILD})"; exit 0; }
  sleep 14
done
echo "아직 미반영. 잠시 후 다시 확인:  curl -s $APPCAST_URL | grep sparkle:version"
