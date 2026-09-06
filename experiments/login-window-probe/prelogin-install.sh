#!/bin/bash
set -euo pipefail
probe_source_dir="$(cd "$(dirname "$0")" && pwd)"
probe_root="$(cd "$probe_source_dir/../.." && pwd)"
probe_bundle="$probe_root/.build/LoginProbe/AiboardLoginProbe.app"
probe_destination="/Library/PrivilegedHelperTools/AiboardLoginProbe.app"
probe_agent="/Library/LaunchAgents/com.davutcaliskan.AiboardLoginProbe.plist"

if [[ $EUID -ne 0 ]]; then
    echo 'Run with sudo only when the pre-login test interruption is coordinated.' >&2
    exit 1
fi
case "${1:-}" in
    install)
        if [[ -e "$probe_destination" || -L "$probe_destination" || -e "$probe_agent" || -L "$probe_agent" ]]; then
            echo 'Probe already installed; refusing to overwrite existing files.' >&2
            exit 1
        fi
        codesign --verify --strict "$probe_bundle"
        plutil -lint "$probe_source_dir/com.davutcaliskan.AiboardLoginProbe.plist"
        ditto "$probe_bundle" "$probe_destination"
        chown -R root:wheel "$probe_destination"
        chmod -R go-w "$probe_destination"
        install -o root -g wheel -m 644 \
            "$probe_source_dir/com.davutcaliskan.AiboardLoginProbe.plist" "$probe_agent"
        echo 'Installed for the next LoginWindow session. No logout or restart was performed.'
        ;;
    remove)
        pkill -x AiboardLoginProbe || true
        rm -f "$probe_agent"
        rm -rf "$probe_destination"
        echo 'Removed only the isolated probe and its launch agent.'
        ;;
    *)
        echo 'Usage: prelogin-install.sh install|remove' >&2
        exit 1
        ;;
esac
