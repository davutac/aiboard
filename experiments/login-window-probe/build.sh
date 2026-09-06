#!/bin/bash
set -euo pipefail
probe_source_dir="$(cd "$(dirname "$0")" && pwd)"
probe_root="$(cd "$probe_source_dir/../.." && pwd)"
probe_bundle="$probe_root/.build/LoginProbe/AiboardLoginProbe.app"
mkdir -p "$probe_bundle/Contents/MacOS" "$probe_root/.build/LoginProbe/ModuleCache"
cp "$probe_source_dir/Info.plist" "$probe_bundle/Contents/Info.plist"
xcrun swiftc -swift-version 6 -default-isolation MainActor -warnings-as-errors \
    -target "$(uname -m)-apple-macos27.0" \
    -module-cache-path "$probe_root/.build/LoginProbe/ModuleCache" \
    "$probe_source_dir/main.swift" -o "$probe_bundle/Contents/MacOS/AiboardLoginProbe"
codesign --force --sign - --options runtime "$probe_bundle"
codesign --verify --strict "$probe_bundle"
plutil -lint "$probe_bundle/Contents/Info.plist" "$probe_source_dir/com.davutcaliskan.AiboardLoginProbe.plist"
"$probe_bundle/Contents/MacOS/AiboardLoginProbe" --self-test
printf '%s\n' "$probe_bundle"
