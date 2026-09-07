#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
CONFIGURATION="${TASTKO_BUILD_CONFIGURATION:-Debug}"

case "$CONFIGURATION" in
    Debug)
        APP_NAME="Tastko Debug"
        ;;
    Release)
        APP_NAME="Tastko"
        ;;
    *)
        echo "Unsupported TASTKO_BUILD_CONFIGURATION: $CONFIGURATION (use Debug or Release)" >&2
        exit 2
        ;;
esac

case "$MODE" in
    build | run | --debug | debug | --logs | logs | --telemetry | telemetry | --verify | verify) ;;
    *)
        echo "usage: $0 [build|run|--debug|--logs|--telemetry|--verify]" >&2
        exit 2
        ;;
esac

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
        -project "$ROOT_DIR/Tastko.xcodeproj" \
        -scheme Tastko \
        -configuration "$CONFIGURATION" \
        -destination "platform=macOS,arch=$HOST_ARCHITECTURE" \
        -derivedDataPath "$DERIVED_DATA_DIR" \
        build
}

open_app() {
    /usr/bin/open -n "$APP_BUNDLE"
}

if [[ "$MODE" != "build" ]]; then
    stop_app
fi
build_app

case "$MODE" in
    build)
        ;;
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
        /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\" AND subsystem == \"com.davutcaliskan.Tastko\""
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
esac
