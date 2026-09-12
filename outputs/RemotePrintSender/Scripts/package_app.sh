#!/bin/zsh
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
scratch_dir="/private/tmp/remote-print-sender-app-build"
app_dir="$project_dir/Remote Print Sender.app"

export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
export CLANG_MODULE_CACHE_PATH="/private/tmp/remote-print-sender-package-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"
swift build --package-path "$project_dir" --scratch-path "$scratch_dir"

rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS"
cp "$project_dir/AppBundle/Info.plist" "$app_dir/Contents/Info.plist"
cp "$scratch_dir/arm64-apple-macosx/debug/RemotePrintSender" "$app_dir/Contents/MacOS/RemotePrintSender"
chmod +x "$app_dir/Contents/MacOS/RemotePrintSender"
codesign --force --sign - "$app_dir"
echo "Packaged: $app_dir"
