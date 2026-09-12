#!/bin/zsh
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
scratch_dir="/private/tmp/remote-print-simulator-app-build"
build_dir="$scratch_dir/arm64-apple-macosx/debug"
app_dir="$project_dir/Remote Print Simulator.app"

export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
swift build --package-path "$project_dir" --scratch-path "$scratch_dir"

rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS"
cp "$project_dir/AppBundle/Info.plist" "$app_dir/Contents/Info.plist"
cp "$build_dir/RemotePrintSimulator" "$app_dir/Contents/MacOS/RemotePrintSimulator"
chmod +x "$app_dir/Contents/MacOS/RemotePrintSimulator"
codesign --force --sign - "$app_dir"
echo "Packaged: $app_dir"
