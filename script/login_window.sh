#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$ROOT/.build/LoginWindow"
PACKAGE="$WORK/Aiboard.pkg"
APP="/Applications/Aiboard.app"
HELPER="/Library/PrivilegedHelperTools/AiboardLoginWindow.app"
AGENT="/Library/LaunchAgents/com.davutcaliskan.Aiboard.LoginWindow.plist"
RECEIPT="com.davutcaliskan.Aiboard.LoginWindowInstaller"
IDENTITY="${AIBOARD_SIGNING_IDENTITY:-Apple Development: Davut - Alper Caliskan (P2DG2M6V9C)}"
TEAM="8J3SWN4QH4"

require_root() {
    if [[ "$EUID" -ne 0 ]]; then
        echo "Run this command with sudo; macOS will request administrator authentication." >&2
        exit 1
    fi
}

verify_bundle() {
    /usr/bin/codesign --verify --deep --strict "$1"
    /usr/bin/codesign --verify -R "=anchor apple generic and certificate leaf[subject.OU] = \"$TEAM\" and identifier \"$2\"" "$1"
}

prepare() {
    [[ "$EUID" -ne 0 ]] || { echo "Prepare the package as your normal user." >&2; exit 1; }
    /usr/bin/xcodebuild -quiet -project "$ROOT/Aiboard.xcodeproj" -scheme Aiboard \
        -configuration Release -destination "platform=macOS,arch=$(uname -m)" \
        -derivedDataPath "$ROOT/.build/DerivedData" ENABLE_CODE_COVERAGE=NO build
    local source="$ROOT/.build/DerivedData/Build/Products/Release/Aiboard.app"
    local staging
    mkdir -p "$WORK"
    /usr/bin/nm "$source/Contents/MacOS/Aiboard" > "$WORK/symbols.txt"
    if /usr/bin/grep -q '___llvm_profile_runtime' "$WORK/symbols.txt"; then
        echo "Refusing to package a production helper with code coverage enabled." >&2
        exit 1
    fi
    staging="$(mktemp -d "$WORK/payload.XXXXXX")"
    trap 'rm -rf "$staging"' RETURN
    mkdir -p "$staging/Applications" "$staging/Library/PrivilegedHelperTools" \
        "$staging/Library/LaunchAgents"
    /usr/bin/ditto --norsrc --noextattr --noacl "$source" "$staging$APP"
    /usr/bin/ditto --norsrc --noextattr --noacl "$source" "$staging$HELPER"
    "$source/Contents/MacOS/Aiboard" --export-login-keyboard "$staging$HELPER/Contents/Resources/LoginKeyboard.json"
    "$source/Contents/MacOS/Aiboard" --validate-login-keyboard "$staging$HELPER/Contents/Resources/LoginKeyboard.json"
    /usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.davutcaliskan.Aiboard.LoginWindow' "$staging$HELPER/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c 'Set :CFBundleName Aiboard Login Keyboard' "$staging$HELPER/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c 'Set :LSUIElement true' "$staging$HELPER/Contents/Info.plist"
    /usr/bin/codesign --force --sign "$IDENTITY" --options runtime --timestamp=none "$staging$HELPER"
    verify_bundle "$staging$APP" com.davutcaliskan.Aiboard
    verify_bundle "$staging$HELPER" com.davutcaliskan.Aiboard.LoginWindow
    /usr/bin/install -m 644 "$ROOT/script/com.davutcaliskan.Aiboard.LoginWindow.plist" "$staging$AGENT"
    /usr/bin/plutil -lint "$staging$AGENT"
    chmod -R go-w "$staging"
    chmod 755 "$staging"
    /usr/bin/pkgbuild --analyze --root "$staging" "$WORK/components.plist"
    python3 - "$WORK/components.plist" <<'PY'
import plistlib, sys
path = sys.argv[1]
with open(path, 'rb') as file:
    components = plistlib.load(file)
for component in components:
    component['BundleIsRelocatable'] = False
    component['BundleIsVersionChecked'] = False
with open(path, 'wb') as file:
    plistlib.dump(components, file)
PY
    /usr/bin/pkgbuild --root "$staging" --ownership recommended --install-location / \
        --component-plist "$WORK/components.plist" \
        --identifier "$RECEIPT" --version "$(date +%Y.%m.%d.%H%M%S)" "$WORK/payload.pkg"
    # Existing parent directories retain their permissions; new files use the root-owned BOM.
    local expanded="$staging/package"
    /usr/sbin/pkgutil --expand "$WORK/payload.pkg" "$expanded"
    python3 - "$expanded/PackageInfo" <<'PY'
import sys, xml.etree.ElementTree as ET
path = sys.argv[1]
tree = ET.parse(path)
tree.getroot().set('overwrite-permissions', 'false')
tree.write(path, encoding='utf-8', xml_declaration=True)
PY
    /usr/sbin/pkgutil --flatten "$expanded" "$PACKAGE"
    echo "Prepared $PACKAGE"
    echo "Installs: $APP, $HELPER, $AGENT"
}

verify() {
    verify_bundle "$APP" com.davutcaliskan.Aiboard
    verify_bundle "$HELPER" com.davutcaliskan.Aiboard.LoginWindow
    /usr/bin/plutil -lint "$AGENT"
    /usr/bin/cmp "$AGENT" "$ROOT/script/com.davutcaliskan.Aiboard.LoginWindow.plist"
    for path in /Library /Library/PrivilegedHelperTools /Library/LaunchAgents "$HELPER" "$AGENT"; do
        [[ ! -L "$path" && "$(stat -f %u "$path")" == 0 ]] || { echo "Unsafe ownership: $path" >&2; exit 1; }
        [[ -z "$(find "$path" -maxdepth 0 -perm +022 -print)" ]] || { echo "Unsafe permissions: $path" >&2; exit 1; }
    done
    [[ -z "$(find "$HELPER" \( ! -user root -o -perm +022 \) -print)" ]] || { echo "Helper contents must be root-owned and not writable by other users." >&2; exit 1; }
    /usr/sbin/pkgutil --pkg-info "$RECEIPT"
    echo "Installed and registered for the next LoginWindow session. Pre-login display/input still needs a manual test."
}

case "${1:-}" in
    prepare) prepare ;;
    install)
        require_root
        [[ -f "$PACKAGE" ]] || { echo "Run prepare first." >&2; exit 1; }
        for path in "$APP" "$HELPER"; do
            if [[ -e "$path" || -L "$path" ]]; then
                [[ ! -L "$path" ]] || { echo "Refusing a symlink at $path" >&2; exit 1; }
                bundle_id="com.davutcaliskan.Aiboard"
                [[ "$path" != "$HELPER" ]] || bundle_id="$bundle_id.LoginWindow"
                verify_bundle "$path" "$bundle_id"
            fi
        done
        if [[ -e "$AGENT" || -L "$AGENT" ]]; then
            [[ ! -L "$AGENT" ]] && /usr/bin/cmp "$AGENT" "$ROOT/script/com.davutcaliskan.Aiboard.LoginWindow.plist"
        fi
        /usr/sbin/installer -pkg "$PACKAGE" -target /
        verify
        ;;
    verify) verify ;;
    remove)
        require_root
        if [[ -e "$HELPER" ]]; then
            verify_bundle "$HELPER" com.davutcaliskan.Aiboard.LoginWindow
        fi
        if [[ -e "$AGENT" ]]; then
            /usr/bin/cmp "$AGENT" "$ROOT/script/com.davutcaliskan.Aiboard.LoginWindow.plist"
        fi
        # Removing the LoginWindow-only agent leaves the user's main app and login item intact.
        /bin/rm -f "$AGENT"
        /bin/rm -rf "$HELPER"
        /usr/sbin/pkgutil --forget "$RECEIPT"
        echo "Pre-login startup removed. The normal Aiboard app remains installed."
        ;;
    *) echo "usage: $0 prepare | install | verify | remove" >&2; exit 2 ;;
esac
