#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
CONFIGURATION="${AIBOARD_BUILD_CONFIGURATION:-Debug}"
APP_NAME="Aiboard"
BUNDLE_ID="com.davutcaliskan.Aiboard"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_DIR="$ROOT_DIR/.build/DerivedData"
APP_BUNDLE="$DERIVED_DATA_DIR/Build/Products/$CONFIGURATION/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
HOST_ARCHITECTURE="$(uname -m)"

stop_app() {
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
}

build_app() {
    xcodebuild \
        -quiet \
        -project "$ROOT_DIR/Aiboard.xcodeproj" \
        -scheme "$APP_NAME" \
        -configuration "$CONFIGURATION" \
        -destination "platform=macOS,arch=$HOST_ARCHITECTURE" \
        -derivedDataPath "$DERIVED_DATA_DIR" \
        build
}

open_app() {
    /usr/bin/open -n "$APP_BUNDLE"
}

stop_app
build_app

case "$MODE" in
    run)
        open_app
        ;;
    --debug | debug)
        lldb -- "$APP_BINARY"
        ;;
    --logs | logs)
        open_app
        /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
        ;;
    --telemetry | telemetry)
        open_app
        /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
        ;;
    --verify | verify)
        open_app

        for _ in {1..20}; do
            if pgrep -x "$APP_NAME" >/dev/null; then
                exit 0
            fi

            sleep 0.25
        done

        echo "$APP_NAME did not launch" >&2
        exit 1
        ;;
    *)
        echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
        exit 2
        ;;
esac
