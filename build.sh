#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${1:-Release}"
DERIVED="$ROOT/.build/dd"
APP="$DERIVED/Build/Products/$CONFIG/FocusGuard.app"
DIST="$ROOT/Dist"
DEST="$DIST/FocusGuard.app"

cd "$ROOT"

echo "==> 构建 FocusGuard（${CONFIG}）"
xcodebuild \
  -project FocusGuard.xcodeproj \
  -scheme FocusGuard \
  -configuration "$CONFIG" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  build \
  -quiet

if [[ ! -d "$APP" ]]; then
  echo "构建产物不存在：$APP" >&2
  exit 1
fi

mkdir -p "$DIST"
rm -rf "$DEST"
ditto "$APP" "$DEST"
xattr -cr "$DEST"
codesign --force --sign - "$DEST"

echo
echo "==> 完成：$DEST"
codesign -dv "$DEST" 2>&1 | sed -n 's/^\(Identifier\|Format\|CodeDirectory\|Signature\)=/\1=/p' || true
echo
echo "运行：open \"$DEST\""
