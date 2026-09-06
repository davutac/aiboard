# Aiboard at the Mac login window

The production Aiboard executable has a separate `--login-window` entry point. It runs as a `LoginWindow` LaunchAgent before normal user sign-in. It displays the actual `PanelEditorLayoutView` and uses Aiboard's normal key rendering, mouse handling, language mapping, modifiers, Caps Lock, repeat handling, and `KeyboardService`. There is no probe or replacement demo keyboard in this installation.

This is separate from the existing-session lock-screen option and from FileVault's preboot unlock screen. It cannot appear in FileVault preboot. Installation does not prove that macOS will display the panel or accept its input before login; that requires the user's manual restart or logout test.

## Profile and session isolation

Package preparation runs as the normal user. It exports the first home panel (falling back to the first panel) and current keyboard width into the helper's signed resource bundle. The export preserves the real key geometry, colors, physical keys, single-character text, and modifiers. It removes multi-character text macros, profile names, application associations, and toolbar actions. The helper has a language-cycle button but no profile editor, debug window, settings window, system-app launcher, or menu bar. Reinstall after changing the home keyboard.

The privileged process reads only this sealed snapshot, rather than user-editable profile packages. It takes an early entry point before the normal SwiftUI app starts: no prediction lifecycle, target-field reads, login-item registration, or normal AppDelegate startup. It checks both root identity and the session's login-complete state. Missing session information fails closed; launchd retries startup if the WindowServer session is not ready. A SIGTERM handler and session timer end the helper when login completes. The LaunchAgent is restricted to `LoginWindow`; it never launches in Aqua.

Input uses paired Core Graphics events through Aiboard's locked-input route, with `CGPreflightPostEventAccess` checked in the actual process/session. The current user's Accessibility authorization does not establish permission for the root pre-login process. A denial appears in the keyboard header; installation does not alter TCC, SIP, FileVault, the authorization database, or any authentication process. No typed text, credentials, or focused-field content is read or logged.

## Build, install, and update

```sh
./script/login_window.sh prepare
sudo ./script/login_window.sh install
./script/login_window.sh verify
```

`prepare` builds Release with code coverage disabled, exports and validates the home keyboard, signs the helper with the configured Apple Development identity, and creates `.build/LoginWindow/Aiboard.pkg`. It refuses binaries containing the LLVM coverage runtime, so the privileged process cannot leave a coverage file when it exits. `AIBOARD_SIGNING_IDENTITY` can select another signing identity in the same team. This is a local development installation, not a notarized distribution package.

The package has no installation scripts and writes only:

- `/Applications/Aiboard.app`: the normal production app.
- `/Library/PrivilegedHelperTools/AiboardLoginWindow.app`: the same production code, with a separate bundle identifier, signed profile snapshot, and login-only entry point.
- `/Library/LaunchAgents/com.davutcaliskan.Aiboard.LoginWindow.plist`: the LoginWindow-only registration.
- The standard Installer receipt `com.davutcaliskan.Aiboard.LoginWindowInstaller`.

The helper's directory and contents must be root-owned and not group/world writable. Installation refuses to overwrite an unrelated app, helper, or agent. Component relocation is disabled so Installer cannot select a development checkout instead. The same prepare/install commands update the app and helper together. `verify` checks both signatures, the exact plist, helper ownership and permissions, and receipt; it does not pretend the LoginWindow job is active during an ordinary signed-in session.

After installation, open `/Applications/Aiboard.app` and enable **Open Aiboard at login** in Settings. When migrating from a development build, turn that setting off and back on from the installed app to register the stable application path. Confirm its enabled state after restarting the app. The helper quits at sign-in, and this normal `SMAppService` item starts the user's app with their current profiles and settings.

## Removal

```sh
sudo ./script/login_window.sh remove
```

This removes only the pre-login helper, its LaunchAgent, and installer receipt. The normal app and its after-login item remain. Remove while signed in; an existing LoginWindow session ends its helper at login. To disable normal startup too, turn off **Open Aiboard at login** in Aiboard Settings.

## Manual acceptance check

The user restarts or logs out manually. At the normal Mac login window, check visibility, language, key selection, and typing. The implementation never initiates logout, reboot, locking, or credential entry for this test. After sign-in, confirm there is one normal Aiboard keyboard and the helper is no longer running. A successful logged-in input test is not a pre-login input result.

## Local verification — 5 September 2026

Release build and all 168 unit tests passed. Strict formatting passed for all 49 changed Swift files. The installed snapshot has 80 buttons, the home panel's 708 × 237 geometry, and the saved 776-point window width.

Installer receipt `2026.09.05.220635`, both application signatures, the exact agent plist, and root ownership/non-writable helper contents were verified after installation. The installed app and helper contain no LLVM coverage runtime. Existing `/Library`, `/Library/LaunchAgents`, and `/Library/PrivilegedHelperTools` permissions were preserved. macOS's background-task database reports both the `/Applications/Aiboard.app` login item and the LoginWindow agent as **enabled, allowed, notified**. The installed app's Settings also reports startup enabled. One normal app process was running; the helper's non-root session guard exited without showing a window or posting input.

The production helper has not yet been observed before login. Visibility, root-session posting permission, actual key acceptance, and handoff through a real login remain the user's manual restart checks.

## References

Apple's [PreLoginAgents sample](https://developer.apple.com/library/archive/samplecode/PreLoginAgents/Introduction/Intro.html) describes LoginWindow agent lifecycle and privileged GUI constraints. Apple's [January 2026 DTS guidance](https://developer.apple.com/forums/thread/814152) reiterates using a GUI agent for pre-login UI and keyboard/mouse event posting. Neither establishes permission or actual input acceptance for this build on this Mac.
