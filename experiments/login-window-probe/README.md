# Login and lock-screen feasibility probe

This standalone macOS 27 helper is an experiment, not Aiboard login support. It does not link the app, load profiles, or change Aiboard's secure-field protection.

Archived feasibility work: use the [production login-window installation](../../docs/login-window-keyboard.md) for Aiboard. Its package never installs this probe.

## What has been checked

- The helper compiles with Swift 6 and warnings treated as errors, signs locally, and passes plist/signature validation.
- `--self-test` constructs paired key-down/up events and checks the nonactivating window configuration. It never posts events or shows a window.
- The normal unlocked-session window was inspected visually and through accessibility. After the user authenticated the permission change, registering the exact current app bundle in System Settings resolved an enabled-switch/runtime-denial mismatch. A fresh launch reports **Event posting: allowed; Accessibility: trusted**.
- The unlocked control test passed: **Send one x** inserted exactly `x` into a new empty TextEdit document, and **Delete one character** restored the empty document. The disposable document was discarded without saving. No lock, logout, system restart, privileged installation, or authentication-policy change has been performed.
- Aiboard's existing `AccessibilityService.focusedKeyboardTarget()` rejects secure text fields. This remains unchanged. The probe separately exercises the lower-level key-posting mechanism used by `CGKeyboardEventPoster`; success here would not establish full-app support.

## Design and limits

The probe uses a nonactivating `NSPanel`, `canBecomeVisibleWithoutLogin = true`, the normal floating level, and `orderFrontRegardless()`. It cannot take keyboard focus and has no editable fields, menus, profile loading, network access, event taps, clipboard access, or inspection of other applications' fields.

Only clicking **Send one x** or **Delete one character** can post a fixed physical key pair using `CGEventSource(.combinedSessionState)` and `.cghidEventTap`. Each attempt first checks `CGPreflightPostEventAccess()`. Denial sends nothing. There is no Return/Enter action, no delayed typing, and no authentication submission. The result label says an event was submitted, not that a target accepted it. Logs contain lifecycle, permission denial, and generic attempt status, never field contents or captured keystrokes.

The helper exits after five minutes or on **Quit probe** / SIGTERM. No automatic relaunch is configured. A manually installed LaunchAgent still needs removal after the experiment; otherwise it can launch once in a future LoginWindow session.

## Build and unlocked control check

From the repository root:

```sh
experiments/login-window-probe/build.sh
open -n .build/LoginProbe/AiboardLoginProbe.app
```

Run GUI checks with ordinary WindowServer access; a restricted shell sandbox can abort AppKit initialization. The app has its own bundle identity and does not inherit Aiboard's Accessibility permission. It is locally ad-hoc signed for this experiment; rebuilding can require renewed permission.

For an input control test, click **Request input permission…** and complete macOS's normal permission UI for **Aiboard Login Probe**. Select a new empty, disposable text field in another app. Click **Refresh status**, then **Send one x** once. Confirm that one character appears, and remove it. Record whether posting was allowed and whether input actually arrived separately. Do not use an existing password or a populated field.

## Coordinated lock-screen test

Do this only when the user is ready to interrupt the live session and has their ordinary way to unlock available.

1. Start a fresh probe so its five-minute timeout has not expired.
2. The user locks the Mac through the normal Apple menu command. Do not log out for this phase.
3. The user reports whether the clearly labeled probe is visible. If it is hidden, that establishes failure of this particular existing-session window configuration; it does not disprove every possible supported approach.
4. Only if the probe is visible and posting is allowed, the user selects an **empty** login field and clicks **Send one x** once. The user observes a character/bullet, then removes the test character. Do not submit it as a login attempt or enter a real password while testing the probe.
5. Quit the probe, or let it expire; unlock normally. Record visibility and input acceptance independently. No screenshots or field reads are needed on the authentication screen.

## Separately coordinated initial-login test

This is an initial **OS login-window** test, not FileVault preboot. Locking an existing session does not establish this phase.

Apple's archived sample uses a root-owned app in `/Library/PrivilegedHelperTools` and a `LoginWindow` LaunchAgent in `/Library/LaunchAgents`. A pre-login agent runs privileged, so installation and logout require explicit coordination after the preparation is reviewed. The script has not been run.

```sh
sudo experiments/login-window-probe/prelogin-install.sh install
```

This installs only:

- `/Library/PrivilegedHelperTools/AiboardLoginProbe.app`
- `/Library/LaunchAgents/com.davutcaliskan.AiboardLoginProbe.plist`

It refuses existing destinations, does not edit authentication policy, and does not trigger logout or restart. After saving work and coordinating the voice-session interruption, the user logs out normally. Observe visibility first. The helper's permission status must be checked in that context; trust granted to the ordinary user-session helper does not prove pre-login permission. If denied, do not attempt a workaround. If allowed, perform only the same empty-field, single-character test without submitting authentication.

Sign back in normally, then remove the experiment:

```sh
sudo experiments/login-window-probe/prelogin-install.sh remove
```

Removal stops only `AiboardLoginProbe` and removes the two exact paths above. The UI otherwise times out after five minutes. If permission was granted, its separate Accessibility entry can be removed in System Settings. Aiboard, FileVault, accounts, authentication rules, and other agents are untouched.

## Record each outcome

| Context | Probe visible? | Posting permission | Test character accepted? | Current result |
| --- | --- | --- | --- | --- |
| Unlocked session | Yes | Allowed / trusted | Yes; exactly one x, then deleted | Permission and actual delivery verified; disposable document discarded |
| Locked existing session | No (user reported) | Granted in unlocked session | Not attempted | Public-window configuration did not remain visible |
| Initial OS login window | Not tested | Not tested | Not tested | Needs reviewed installation and coordinated logout |

## Sources

- [Apple PreLoginAgents sample](https://developer.apple.com/library/archive/samplecode/PreLoginAgents/Introduction/Intro.html), version 1.1 from 2014. The downloaded sample's README, Cocoa delegate, and LaunchAgent plist were inspected; its prebuilt binaries were not executed. It documents the assistive-technology use case, special visibility flag, privileged context, SIGTERM lifecycle, and warns that event taps do not work by default. Event tapping and posting are distinct; the warning does not prove key posting succeeds or fails here.
- [NSWindow.canBecomeVisibleWithoutLogin](https://developer.apple.com/documentation/appkit/nswindow/canbecomevisiblewithoutlogin). This documents visibility eligibility, not acceptance of synthetic input by protected fields.

The archived mechanism is a candidate to verify on macOS 27, not a current compatibility guarantee. Do not change authorization plug-ins, TCC databases, SIP, FileVault, specialist system-user identities, or authentication policy for this experiment.
