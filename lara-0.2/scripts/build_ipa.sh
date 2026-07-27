#!/bin/bash
set -euo pipefail

rm -rf build/
mkdir -p build

echo "Build Started!"
echo

xcodebuild \
  -project lara.xcodeproj \
  -scheme lara \
  -configuration Debug \
  -sdk iphoneos \
  -arch arm64e \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGN_ENTITLEMENTS="Config/lara.entitlements" \
  archive \
  -archivePath "$PWD/build/lara.xcarchive" \
  2>&1 | tee "$PWD/build/xcodebuild.log"

BUILD_STATUS=${PIPESTATUS[0]}

if [ "$BUILD_STATUS" -ne 0 ]; then
  echo
  echo "========================================"
  echo "XCODEBUILD FAILED - EXIT CODE: $BUILD_STATUS"
  echo "========================================"
  echo
  echo "===== XCODEBUILD LOG ====="
  cat "$PWD/build/xcodebuild.log"
  echo
  exit "$BUILD_STATUS"
fi

echo
echo "Xcode archive completed successfully."

APP_PATH="$PWD/build/lara.xcarchive/Products/Applications/lara.app"

if [ ! -d "$APP_PATH" ]; then
  echo "ERROR: Missing app at:"
  echo "$APP_PATH"
  exit 1
fi

rm -rf "$PWD/build/Payload"
mkdir -p "$PWD/build/Payload"

cp -R "$APP_PATH" "$PWD/build/Payload/"

plutil -replace UIFileSharingEnabled -bool YES \
  "$PWD/build/Payload/lara.app/Info.plist"

if ! command -v ldid >/dev/null 2>&1; then
  echo "ERROR: ldid not installed"
  exit 1
fi

ldid -SConfig/lara.entitlements \
  "$PWD/build/Payload/lara.app/lara"

(cd "$PWD/build" && /usr/bin/zip -qry lara.ipa Payload)

echo
echo "========================================"
echo "BUILD SUCCESSFUL!"
echo "IPA: build/lara.ipa"
echo "========================================"