#!/bin/bash
set -euo pipefail
: "${THEOS:?Set THEOS to a writable build-tools directory}"
brew list ldid >/dev/null 2>&1 || brew install ldid
if [[ ! -d "$THEOS/.git" ]]; then
  git clone --recursive https://github.com/theos/theos.git "$THEOS"
fi
git -C "$THEOS" checkout 304e0799973e8145f32e4ca2de6c747a84b758ce
git -C "$THEOS" submodule update --init --recursive
SDK_REPO="${THEOS}-sdks"
if [[ ! -d "$SDK_REPO/.git" ]]; then
  git clone --filter=blob:none --no-checkout https://github.com/theos/sdks.git "$SDK_REPO"
fi
git -C "$SDK_REPO" sparse-checkout set iPhoneOS14.5.sdk
git -C "$SDK_REPO" checkout 0222fd5413cf4b9af096f37b4621afa2688572f7
mkdir -p "$THEOS/sdks"
ln -sfn "$SDK_REPO/iPhoneOS14.5.sdk" "$THEOS/sdks/iPhoneOS14.5.sdk"
test -f "$THEOS/sdks/iPhoneOS14.5.sdk/SDKSettings.plist"
