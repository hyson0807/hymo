#!/bin/bash
#
# 하이모 릴리스 자동화 — 사용법:  ./release.sh <공증된 hymo.app 경로>
#   예) ./release.sh /Users/hyson/hyson_works/PROJECTS/hymo_apps/hymo.app
#
# 사람이 먼저: Xcode에서 버전 올리고 → Product > Archive → Organizer에서
#             Distribute App > Direct Distribution(자동 공증) > Export 로 .app 추출.
# 그 다음 이 스크립트: 공증본을 받아 zip/dmg + Sparkle 서명 + appcast + hyson_kr 배포.
#   (앱을 다시 서명/빌드하지 않는다 → 공증 유지)
#
# 버전·빌드 번호는 .app 안의 Info.plist에서 읽는다(따로 인자로 안 받음).
set -euo pipefail

# ── 경로/상수 ───────────────────────────────────────────────
HYMO="/Users/hyson/hyson_works/PROJECTS/hymo"
KR="/Users/hyson/hyson_works/hyson_kr"
DL="$KR/public/downloads"
APPCAST_URL="https://hyson.kr/downloads/appcast.xml"
MIN_MACOS="14.0"   # appcast 최소 지원 macOS (배포 타깃과 일치)

bold() { printf "\033[1m%s\033[0m\n" "$1"; }
ok()   { printf "\033[32m✓\033[0m %s\n" "$1"; }
die()  { printf "\033[31m✗ %s\033[0m\n" "$1" >&2; exit 1; }
step() { printf "\n\033[1m▶ %s\033[0m\n" "$1"; }
plist(){ /usr/libexec/PlistBuddy -c "Print :$1" "$2" 2>/dev/null; }

# ── 0) 인자 = 공증된 .app 경로 ──────────────────────────────
APP="${1:-}"
[ -n "$APP" ] || die "공증된 .app 경로를 주세요.  예) ./release.sh ~/hymo_apps/hymo.app"
APP="${APP%/}"
[ -d "$APP" ] || die "경로에 .app 이 없음: $APP"

# ── 1) 앱 검증: 공증 / 샌드박스 / 버전 ──────────────────────
step "앱 검증"
NEW_SHORT=$(plist CFBundleShortVersionString "$APP/Contents/Info.plist")
NEW_BUILD=$(plist CFBundleVersion "$APP/Contents/Info.plist")
[ -n "$NEW_SHORT" ] && [ -n "$NEW_BUILD" ] || die "앱에서 버전을 못 읽음"
xcrun stapler validate "$APP" >/dev/null 2>&1 \
  || die "공증(스테이플) 안 됨. Xcode에서 Distribute App > Direct Distribution 으로 공증·Export 했는지 확인."
SBX=$(codesign -d --entitlements - --xml "$APP" 2>/dev/null | \
      python3 -c "import sys,plistlib;print(plistlib.loads(sys.stdin.buffer.read()).get('com.apple.security.app-sandbox'))")
[ "$SBX" = "False" ] || die "App Sandbox 가 켜져있음(=$SBX). Server 탭 lsof/kill 막힘."
ok "버전 ${NEW_SHORT}(${NEW_BUILD}), 공증됨(stapled), 비샌드박스"

# ── 2) 라이브 버전과 비교 (낮으면 거부, 같으면 확인) ────────
step "라이브 버전 확인"
LIVE_XML=$(curl -fsS "${APPCAST_URL}?t=$(date +%s)") || die "라이브 appcast를 못 읽음: $APPCAST_URL"
LIVE_BUILD=$(echo "$LIVE_XML" | grep -oE '<sparkle:version>[0-9]+' | grep -oE '[0-9]+' | head -1)
[ -n "$LIVE_BUILD" ] || die "라이브 sparkle:version 을 못 읽음"
if [ "$NEW_BUILD" -lt "$LIVE_BUILD" ]; then
  die "새 build($NEW_BUILD) < 라이브($LIVE_BUILD). 버전을 더 높여 아카이브하세요."
elif [ "$NEW_BUILD" -eq "$LIVE_BUILD" ]; then
  printf "build %s 은 라이브와 동일(공증본 교체 등). 계속할까요? [y/N] " "$NEW_BUILD"
  read -r A || A=""; [ "$A" = "y" ] || die "취소됨"
fi
ok "라이브 build ${LIVE_BUILD} → 배포 build ${NEW_BUILD}"

# ── 3) 릴리스 노트 + 시작 확인 ──────────────────────────────
printf "릴리스 노트 한 줄 (엔터=생략): "
read -r NOTES || NOTES=""
echo
bold "배포: ${NEW_SHORT} (build ${NEW_BUILD})"
printf "계속할까요? [y/N] "; read -r ANS || ANS=""; [ "$ANS" = "y" ] || die "취소됨"

# ── 4) 소스 버전 동기화 (저장소가 릴리스 버전과 어긋나지 않게) ─
step "소스 버전 동기화"
cd "$HYMO"
sed -i '' "s/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = ${NEW_SHORT};/g; \
           s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = ${NEW_BUILD};/g" \
           hymo.xcodeproj/project.pbxproj
HYMO_CHANGED=0
if ! git diff --quiet hymo.xcodeproj/project.pbxproj; then
  git add hymo.xcodeproj/project.pbxproj
  git commit -q -m "버전 ${NEW_SHORT} (build ${NEW_BUILD})"
  HYMO_CHANGED=1
  ok "hymo 버전 커밋"
else
  ok "pbxproj 이미 ${NEW_SHORT}(${NEW_BUILD}) — 변경 없음"
fi

# ── 5) zip + dmg (재서명 금지 → 공증 유지) ──────────────────
step "업데이트 zip + dmg 생성"
OUT=/tmp/hymo_release_out; rm -rf "$OUT"; mkdir -p "$OUT"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT/hymo_update.zip"
STAGE=/tmp/hymo_dmg_stage; rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"; ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Hymo" -srcfolder "$STAGE" -ov -format UDZO "$OUT/hymo_app.dmg" >/dev/null
ok "zip $(stat -f%z "$OUT/hymo_update.zip") bytes, dmg 생성"

# ── 6) Sparkle EdDSA 서명 ───────────────────────────────────
step "Sparkle 서명"
SIGN=$(find /tmp/hymo_spm ~/Library/Developer/Xcode/DerivedData -name sign_update -path '*Sparkle*' 2>/dev/null | head -1)
[ -n "$SIGN" ] || die "sign_update 도구를 못 찾음 (Sparkle SPM이 빌드된 적 있어야 함)"
SIGOUT=$("$SIGN" "$OUT/hymo_update.zip")
EDSIG=$(echo "$SIGOUT" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')
LEN=$(echo "$SIGOUT"   | sed -n 's/.*length="\([0-9]*\)".*/\1/p')
[ -n "$EDSIG" ] && [ -n "$LEN" ] || die "서명 파싱 실패: $SIGOUT"
ok "서명 완료 (length=$LEN)"

# ── 7) appcast.xml (item 1개만 유지) ────────────────────────
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
            <sparkle:minimumSystemVersion>${MIN_MACOS}</sparkle:minimumSystemVersion>
        </item>
    </channel>
</rss>
EOF
ok "appcast 작성"

# ── 8) hyson_kr 복사 + 검증 ─────────────────────────────────
step "산출물 복사"
cp "$OUT/hymo_update.zip" "$DL/hymo_update.zip"
cp "$OUT/hymo_app.dmg"    "$DL/hymo_app.dmg"
ZIPSIZE=$(stat -f%z "$DL/hymo_update.zip")
[ "$ZIPSIZE" = "$LEN" ] || die "zip 크기($ZIPSIZE) != appcast length($LEN)"
ok "복사 완료, length 일치($LEN)"

# ── 9) 커밋 ────────────────────────────────────────────────
step "커밋"
cd "$KR"
git add public/downloads/appcast.xml public/downloads/hymo_update.zip public/downloads/hymo_app.dmg
git commit -q -m "하이모 ${NEW_SHORT} (build ${NEW_BUILD}) 배포 (공증본)" && ok "hyson_kr 커밋"

# ── 10) push 확인 (되돌리기 어려운 라이브 배포) ─────────────
echo
bold "여기서 push 하면 전체 사용자에게 ${NEW_SHORT} 자동업데이트 / 신규 다운로드가 갱신됩니다."
printf "라이브에 배포(push)할까요? [y/N] "; read -r ANS || ANS=""
if [ "$ANS" != "y" ]; then
  echo "push 보류. 나중에 직접:  (cd $HYMO && git push) ; (cd $KR && git push)"
  exit 0
fi

step "push"
[ "$HYMO_CHANGED" = "1" ] && ( cd "$HYMO" && git push -q origin main ) && ok "hymo push"
( cd "$KR" && git push -q origin main ) && ok "hyson_kr push"

# ── 11) 라이브 반영 확인 ────────────────────────────────────
step "라이브 반영 확인 (자동배포 1~3분)"
for i in $(seq 1 12); do
  L=$(curl -sI --max-time 10 "https://hyson.kr/downloads/hymo_update.zip?t=$(date +%s)" | grep -i content-length | grep -oE '[0-9]+' || true)
  printf "  [%s] 라이브 zip=%s (목표 %s)\n" "$i" "${L:-?}" "$LEN"
  [ "$L" = "$LEN" ] && { ok "라이브 반영 완료 — ${NEW_SHORT} (${NEW_BUILD}) 공증본"; exit 0; }
  sleep 14
done
echo "아직 미반영. 잠시 후:  curl -sI https://hyson.kr/downloads/hymo_update.zip | grep -i content-length"
