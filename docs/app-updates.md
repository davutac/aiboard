# App updates

Tastko uses Sparkle 2.9.6 for updates outside the Mac App Store.

## In the app

- Use **Check for Updates…** in the menu bar menu, the application menu, or **Settings → Updates**.
- Sparkle asks permission to check automatically, normally on the second launch. Its default interval is 24 hours. The Settings toggle uses Sparkle's own persisted preference.
- When a scheduled check finds an update, a blue download button appears immediately to the left of the keyboard's accessibility icon. Clicking it opens Sparkle's download/install flow, or brings the current update progress into focus. The button clears when that update session finishes, including dismissal or skipping.
- Scheduled update reminders use the button without taking focus from the app being typed into. The button is disabled while the screen is locked.
- The pre-login keyboard and command-line export/validation modes never start the updater.

## Hosting

The appcast URL is:

```text
https://github.com/davutac/tastko/releases/latest/download/appcast.xml
```

Each release includes its DMG and an `appcast.xml` whose enclosure points to that exact tag's DMG. The latest stable GitHub release supplies the live feed. Prereleases are published with `--latest=false`, so they aren't offered through this feed. Only the latest full update is needed; delta updates aren't generated.

**The feed and downloads won't work while this repository is private.** Sparkle makes unauthenticated HTTPS requests; it doesn't ship a GitHub token. Once the repository is public and a stable release containing `appcast.xml` is published, the same URL works without an app change.

## Signing configuration

A Tastko-specific Ed25519 key is stored using Sparkle's `generate_keys` tool:

- Keychain account: `com.davutcaliskan.Tastko`.
- Public key: embedded through the `SPARKLE_PUBLIC_ED_KEY` build setting and stored as the GitHub Actions repository secret of the same name.
- Private key: stored in the macOS login Keychain and the repository's `SPARKLE_PRIVATE_ED_KEY` Actions secret. It is never embedded in the app or committed.

Keep a secure backup of the private key. Existing installations trust this key; don't regenerate it for each release.

After resolving packages, the tools are in:

```sh
sparkle_bin=.build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin
"$sparkle_bin/generate_keys" --account com.davutcaliskan.Tastko -p
```

To restore GitHub Actions configuration from this Mac's Keychain:

```sh
set -euo pipefail
umask 077
key_directory="$(mktemp -d)"
trap 'rm -rf "$key_directory"' EXIT
"$sparkle_bin/generate_keys" --account com.davutcaliskan.Tastko -x "$key_directory/private.key"
gh secret set SPARKLE_PRIVATE_ED_KEY --repo davutac/tastko < "$key_directory/private.key"
"$sparkle_bin/generate_keys" --account com.davutcaliskan.Tastko -p | \
  gh secret set SPARKLE_PUBLIC_ED_KEY --repo davutac/tastko
```

On another Mac, import a secure key backup with `generate_keys --account com.davutcaliskan.Tastko -f /path/to/private.key` first. Debug builds need only the committed public key to check for updates.

## Release workflow

The tag-triggered workflow archives and exports the app with Developer ID signing, then notarizes and staples both the app and DMG. Publication requires Apple to accept both submissions and Gatekeeper to verify the results. Sparkle's `generate_appcast` signs the final DMG, receiving its private key through standard input. The feed includes the signature, version, build number, minimum macOS version, and hardware requirements.

The scripts in `.github/scripts/` install temporary signing credentials, check notarization results, and remove credentials after the job, including on failure.

Packaging follows [Sparkle's distribution guidance](https://sparkle-project.org/documentation/#4-distributing-your-app) and [publishing recommendations](https://sparkle-project.org/documentation/publishing/): an APFS disk image with LZFSE compression, preserved framework symlinks and permissions, and an `/Applications` shortcut. Appcast generation happens after signing, notarization, and stapling so the Ed25519 signature covers the final download. Each release also retains the app and Sparkle helper debug symbols in a separate `dSYMs.zip` archive for crash symbolication; this archive is added after appcast generation so Sparkle does not treat it as an update.

`SUVerifyUpdateBeforeExtraction` requires archive signature validation before extraction. Ed25519 update signing is separate from Apple code signing and notarization. Developer ID releases use the normal app entitlements, including the registered App Group, and export the archive so Sparkle's nested helpers are signed correctly. They do not disable library validation. Previously published ad-hoc releases remain unchanged.

Configure these GitHub Actions **repository secrets**:

| Secret | Value |
| --- | --- |
| `APPLE_TEAM_ID` | Apple Developer team ID |
| `APPLE_API_KEY_ID` | Notarization API key ID |
| `APPLE_API_ISSUER_ID` | App Store Connect API issuer ID |
| `APPLE_CERTIFICATE_P12_BASE64` | Base64-encoded Developer ID Application certificate and matching private key exported as a password-protected `.p12` |
| `APPLE_CERTIFICATE_PASSWORD` | Password for that `.p12` |
| `APPLE_PROVISIONING_PROFILE_BASE64` | Base64-encoded Developer ID profile for `com.davutcaliskan.Tastko`, containing `group.com.davutcaliskan.Tastko` and the signing certificate |
| `APPLE_API_PRIVATE_KEY` | The notarization API key's complete `.p8` contents |
| `SPARKLE_PUBLIC_ED_KEY` | Sparkle update public key matching the embedded key |
| `SPARKLE_PRIVATE_ED_KEY` | Existing Sparkle update private key |

All release configuration is stored in repository secrets. The notarization API key uses the Developer role.

Local Apple signing credentials are stored in the Git-ignored `.signing/` directory with owner-only permissions. Pass secret values to `gh secret set` through standard input. When rotating the certificate, replace both the `.p12` and the profile, which must include the replacement certificate. Keep the Sparkle key stable so installed copies continue to trust updates.

Apple references: [customizing notarization](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow), [App Group provisioning](https://developer.apple.com/documentation/xcode/accessing-app-group-containers).

Keep `CURRENT_PROJECT_VERSION` increasing; the workflow uses `GITHUB_RUN_NUMBER`. A release published before this integration must be updated manually once to get Sparkle support. The separately installed login-window copy also still requires its own installation step.

## Verification

1. Build and launch Tastko; confirm **Check for Updates…** is enabled and the Settings preference persists.
2. While the repository is private, a manual check should show Sparkle's feed retrieval error.
3. Once public, publish a stable release and run a lower-build-number copy installed in `/Applications`.
4. With automatic checks enabled, let Sparkle find that release. Confirm the blue update button appears to the left of accessibility without stealing focus.
5. Click the button, download the update, and confirm installation and relaunch. Also check cancel/skip clears the button and a failed download can be retried.
6. Confirm an up-to-date build reports no updates and prereleases aren't offered by the stable feed.

You can override `SPARKLE_FEED_URL` on an `xcodebuild` invocation for a separate HTTPS test feed. Test feeds must contain archives signed with the matching key; install/relaunch testing needs two real builds.

References: [Sparkle setup](https://sparkle-project.org/documentation/), [gentle reminders](https://sparkle-project.org/documentation/gentle-reminders/), [publishing updates](https://sparkle-project.org/documentation/publishing/).
