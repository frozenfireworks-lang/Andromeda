#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$PWD"
: "${THEOS:?Run scripts/setup-theos.sh first}"
command -v ldid >/dev/null
command -v xcodebuild >/dev/null
CONFIGURATION=Release
mkdir -p build
# Always rebuild the pinned RootHelper source; never ship the prebuilt repository binary.
git submodule update --init --recursive
make -C RootHelper clean
make -C RootHelper -j2 FINALPACKAGE=1
HELPER="$ROOT/RootHelper/.theos/obj/GeraniumRootHelper"
test -f "$HELPER"
cp "$HELPER" Geranium/GeraniumRootHelper
chmod +x Geranium/GeraniumRootHelper
ldid -SRootHelper/entitlements.plist Geranium/GeraniumRootHelper
xcodebuild -resolvePackageDependencies -project Geranium.xcodeproj -scheme Geranium
xcodebuild -project Geranium.xcodeproj -scheme Geranium -configuration "$CONFIGURATION" \
  -derivedDataPath "$ROOT/build/DerivedData" -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' DEVELOPMENT_TEAM='' \
  ENABLE_DEBUG_DYLIB=NO ONLY_ACTIVE_ARCH=NO build | tee build/xcodebuild.log
SOURCE_APP="$ROOT/build/DerivedData/Build/Products/$CONFIGURATION-iphoneos/Geranium.app"
# Restrict cleanup to this script's packaging staging directory.
rm -rf "$ROOT/build/Payload"
mkdir -p "$ROOT/build/Payload"
cp -R "$SOURCE_APP" "$ROOT/build/Payload/Geranium.app"
APP="$ROOT/build/Payload/Geranium.app"
find "$APP" -type d -name _CodeSignature -prune -exec rm -rf '{}' +
find "$APP" -name embedded.mobileprovision -delete
ldid -Sentitlements.plist "$APP/Geranium"
ldid -SRootHelper/entitlements.plist "$APP/GeraniumRootHelper"
EXT="$APP/PlugIns/Bookmark Location in Geranium.appex"
ldid -S"Bookmark Location in Geranium/entitlements.plist" "$EXT/Bookmark Location in Geranium"
# Swift libraries / dynamic frameworks must also carry an ad-hoc signature.
while IFS= read -r -d '' binary; do ldid -S "$binary"; done < <(find "$APP/Frameworks" -type f -name '*.dylib' -print0 2>/dev/null || true)
python3 scripts/verify-package.py "$APP"
cd build
rm -f Andromeda-v2.5.2-japan-gps.tipa
zip -qry Andromeda-v2.5.2-japan-gps.tipa Payload
shasum -a 256 Andromeda-v2.5.2-japan-gps.tipa > SHA256SUMS.txt
