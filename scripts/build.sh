#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
cd "$project_dir"
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$project_dir/.build/ModuleCache}"
swift build -c release --disable-sandbox
app_bundle="$project_dir/dist/PeripheralKit.app"
mkdir -p "$app_bundle/Contents/MacOS"
install -m 755 .build/release/PeripheralKit "$app_bundle/Contents/MacOS/PeripheralKit"
install -m 644 resources/Info.plist "$app_bundle/Contents/Info.plist"
codesign --force --sign "${CODESIGN_IDENTITY:--}" --identifier com.local.peripheralkit "$app_bundle"
codesign --verify --strict "$app_bundle"
print "App: $app_bundle"
