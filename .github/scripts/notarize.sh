#!/bin/bash
set -euo pipefail

artifact="${1:?Supply the archive to notarize}"
result="$(mktemp "$RUNNER_TEMP/notarization.XXXXXX")"
trap 'rm -f "$result"' EXIT
credentials=(
  --key "$RUNNER_TEMP/apple-signing/AuthKey.p8"
  --key-id "$APPLE_API_KEY_ID"
  --issuer "$APPLE_API_ISSUER_ID"
)

submitted=true
xcrun notarytool submit "$artifact" "${credentials[@]}" \
  --wait --timeout 20m --output-format json > "$result" || submitted=false
cat "$result"
status="$(plutil -extract status raw -o - "$result" 2>/dev/null || true)"
if [[ "$submitted" != true || "$status" != Accepted ]]; then
  submission_id="$(plutil -extract id raw -o - "$result" 2>/dev/null || true)"
  if [[ -n "$submission_id" ]]; then
    xcrun notarytool log "$submission_id" "${credentials[@]}" || true
  fi
  echo '::error::Apple notarization did not complete with Accepted status.'
  exit 1
fi
