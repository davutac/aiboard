#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Tastko Debug"
BUNDLE_ID="com.davutcaliskan.Tastko.debug"
BUILT_APP="$ROOT_DIR/.build/DerivedData/Build/Products/Debug/$APP_NAME.app"
INSTALLED_APP="/Applications/$APP_NAME.app"

# MARK: - App Identity
verify_debug_app() {
    local bundle_id
    if [[ -L "$1" ]]; then
        echo "Refusing to use a symbolic link at $1." >&2
        exit 1
    fi
    bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$1/Contents/Info.plist")"
    if [[ "$bundle_id" != "$BUNDLE_ID" ]]; then
        echo "Expected Debug bundle ID $BUNDLE_ID at $1, found $bundle_id." >&2
        exit 1
    fi
}

# MARK: - Cleanup
cleanup() {
    if [[ -e "$STAGING_DIR/previous.app" && ! -e "$INSTALLED_APP" ]]; then
        if ! mv "$STAGING_DIR/previous.app" "$INSTALLED_APP"; then
            echo "Previous app preserved at $STAGING_DIR/previous.app." >&2
            return
        fi
    fi
    rm -rf "$STAGING_DIR"
}

echo "Building $APP_NAME..."
TASTKO_BUILD_CONFIGURATION=Debug "$ROOT_DIR/script/build_and_run.sh" build
verify_debug_app "$BUILT_APP"
/usr/bin/codesign --verify --deep --strict "$BUILT_APP"
if [[ -e "$INSTALLED_APP" || -L "$INSTALLED_APP" ]]; then
    verify_debug_app "$INSTALLED_APP"
fi

# Stage the replacement before stopping Debug; keep the old app until the move succeeds.
STAGING_DIR="$(mktemp -d '/Applications/.tastko-debug.XXXXXX')"
trap cleanup EXIT
/usr/bin/ditto "$BUILT_APP" "$STAGING_DIR/$APP_NAME.app"

echo "Stopping $APP_NAME..."
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
for _ in {1..40}; do
    if ! pgrep -x "$APP_NAME" >/dev/null; then
        break
    fi
    sleep 0.25
done
if pgrep -x "$APP_NAME" >/dev/null; then
    echo "$APP_NAME did not stop; installation cancelled." >&2
    exit 1
fi

echo "Installing $INSTALLED_APP..."
if [[ -e "$INSTALLED_APP" ]]; then
    mv "$INSTALLED_APP" "$STAGING_DIR/previous.app"
fi
mv "$STAGING_DIR/$APP_NAME.app" "$INSTALLED_APP"

echo "Starting $APP_NAME..."
/usr/bin/open -n "$INSTALLED_APP"
for _ in {1..40}; do
    if pgrep -f '^/Applications/Tastko Debug[.]app/Contents/MacOS/Tastko Debug($| )' >/dev/null; then
        echo "$APP_NAME is running from /Applications."
        exit 0
    fi
    sleep 0.25
done

echo "$APP_NAME was installed but did not launch." >&2
exit 1
