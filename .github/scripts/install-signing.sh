#!/bin/bash
set -euo pipefail

for name in \
  APPLE_CERTIFICATE_P12_BASE64 APPLE_CERTIFICATE_PASSWORD \
  APPLE_PROVISIONING_PROFILE_BASE64 APPLE_API_PRIVATE_KEY \
  APPLE_API_KEY_ID APPLE_API_ISSUER_ID; do
  if [[ -z "${!name:-}" ]]; then
    echo "::error::Missing $name. See docs/app-updates.md."
    exit 1
  fi
done

umask 077
signing_dir="$RUNNER_TEMP/apple-signing"
mkdir -p "$signing_dir"
printf '%s' "$APPLE_CERTIFICATE_P12_BASE64" | base64 --decode > "$signing_dir/certificate.p12"
printf '%s' "$APPLE_PROVISIONING_PROFILE_BASE64" | base64 --decode > "$signing_dir/profile.provisionprofile"
printf '%s' "$APPLE_API_PRIVATE_KEY" > "$signing_dir/AuthKey.p8"

keychain="$signing_dir/signing.keychain-db"
keychain_password="$(openssl rand -base64 32)"
echo "::add-mask::$keychain_password"
security create-keychain -p "$keychain_password" "$keychain"
security set-keychain-settings -lut 7200 "$keychain"
security unlock-keychain -p "$keychain_password" "$keychain"
security import "$signing_dir/certificate.p12" -P "$APPLE_CERTIFICATE_PASSWORD" \
  -k "$keychain" -T /usr/bin/codesign -T /usr/bin/security
curl --fail --silent --show-error --location \
  https://www.apple.com/certificateauthority/DeveloperIDG2CA.cer \
  --output "$signing_dir/DeveloperIDG2CA.cer"
security import "$signing_dir/DeveloperIDG2CA.cer" -k "$keychain"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s \
  -k "$keychain_password" "$keychain"
security list-keychains -d user -s "$keychain"
security find-identity -v -p codesigning "$keychain"

security cms -D -i "$signing_dir/profile.provisionprofile" > "$signing_dir/profile.plist"
profile_uuid="$(/usr/libexec/PlistBuddy -c 'Print UUID' "$signing_dir/profile.plist")"
profile_dir="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
mkdir -p "$profile_dir"
echo "profile_uuid=$profile_uuid" >> "$GITHUB_OUTPUT"
cp "$signing_dir/profile.provisionprofile" "$profile_dir/$profile_uuid.provisionprofile"
