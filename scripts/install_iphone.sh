#!/bin/zsh
set -euo pipefail
INKREADER_ROOT="${0:A:h:h}"
INKREADER_DEVICE_ID="${1:-00008150-00056D243A20401C}"
cd "$INKREADER_ROOT"
mkdir -p build
echo "正在为 iPhone 编译墨卷……"
if ! xcodebuild -project InkReader.xcodeproj -scheme InkReader -configuration Release \
    -destination "id=$INKREADER_DEVICE_ID" -derivedDataPath build/Device build \
    CODE_SIGN_STYLE=Automatic > build/device-build.log 2>&1; then
    tail -n 60 build/device-build.log
    exit 1
fi
xcrun devicectl device install app --device "$INKREADER_DEVICE_ID" "$INKREADER_ROOT/build/Device/Build/Products/Release-iphoneos/InkReader.app"
xcrun devicectl device process launch --device "$INKREADER_DEVICE_ID" com.edy.inkreader
echo "墨卷已安装并打开。"
