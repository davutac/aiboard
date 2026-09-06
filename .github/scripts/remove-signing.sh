#!/bin/bash
set -euo pipefail

keychain="$RUNNER_TEMP/apple-signing/signing.keychain-db"
if [[ -f "$keychain" ]]; then
  security delete-keychain "$keychain"
fi
if [[ -n "$PROFILE_UUID" ]]; then
  rm -f "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles/$PROFILE_UUID.provisionprofile"
fi
rm -rf "$RUNNER_TEMP/apple-signing"
