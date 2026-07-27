#!/bin/bash

set -e

# Go to lara-0.2/
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

APPLICATION_NAME="lara"
BUILD_DIR="$PROJECT_ROOT/build"
DERIVED_DATA="$BUILD_DIR/DerivedDataApp"

echo "[*] $APPLICATION_NAME Build Script"
echo "[*] Project root: $PROJECT_ROOT"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "[*] Building..."

if [[ "$*" == *"--debug"* ]]; then
    CONFIGURATION="Debug"
    IPA_NAME="$APPLICATION_NAME.debug.ipa"
else
    CONFIGURATION="Release"
    IPA_NAME="$APPLICATION_NAME.ipa"
fi

xcodebuild \
    -project "$PROJECT_ROOT/$APPLICATION_NAME.xcodeproj" \
    -scheme "$APPLICATION_NAME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA" \
    -destination 'generic/platform=iOS' \
    clean build \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_ENTITLEMENTS="" \
    CODE_SIGNING_ALLOWED=NO

APP_PATH="$DERIVED_DATA/Build/Products/$CONFIGURATION-iphoneos/$APPLICATION_NAME.app"

if [ ! -d "$APP_PATH" ]; then
    echo "[!] ERROR: App not found:"
    echo "$APP_PATH"
    exit 1
fi

echo "[*] App found:"
echo "$APP_PATH"

TARGET_APP="$BUILD_DIR/$APPLICATION_NAME.app"

cp -R "$APP_PATH" "$TARGET_APP"

echo "[*] Stripping signature..."

codesign --remove-signature "$TARGET_APP" || true

if [ -e "$TARGET_APP/_CodeSignature" ]; then
    rm -rf "$TARGET_APP/_CodeSignature"
fi

if [ -e "$TARGET_APP/embedded.mobileprovision" ]; then
    rm -f "$TARGET_APP/embedded.mobileprovision"
fi

echo "[*] Packaging..."

cd "$BUILD_DIR"

rm -rf Payload
mkdir Payload

cp -R "$APPLICATION_NAME.app" "Payload/$APPLICATION_NAME.app"

zip -qr "$IPA_NAME" Payload

rm -rf Payload
rm -rf "$APPLICATION_NAME.app"
rm -rf DerivedDataApp

echo "[*] IPA created:"
echo "$BUILD_DIR/$IPA_NAME"

if [ ! -f "$BUILD_DIR/$IPA_NAME" ]; then
    echo "[!] ERROR: IPA was not created"
    exit 1
fi

echo "[*] All done!"