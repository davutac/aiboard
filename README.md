# Aiboard

Aiboard is a floating accessibility keyboard for macOS 27 and later. It uses layouts from macOS Panel Editor and types into other apps without taking focus. Word suggestions come from macOS, with optional on-device suggestions from Apple Intelligence.

## Getting started

### Requirements

- macOS 27 or later and Xcode with a macOS 27 SDK or later.
- A keyboard panel saved with macOS Panel Editor.
- Accessibility permission to type into other apps.

AI suggestions need a Mac that supports Apple Intelligence, with Apple Intelligence enabled and its model downloaded. Native predictions work without it.

### Build and launch

Clone the private repository using a GitHub account with access:

```sh
git clone https://github.com/davutac/aiboard.git
cd aiboard
```

Open `Aiboard.xcodeproj` in Xcode, or build and launch from the repository root:

```sh
./script/build_and_run.sh
```

Swift Package Manager resolves the `Defaults` and `Sparkle` dependencies automatically.

1. Allow Aiboard in **System Settings → Privacy & Security → Accessibility**.
2. Use Aiboard's panel menu to open Panel Editor, save a keyboard, and reload profiles.
3. Select a text field in another app, then click keys in Aiboard to type.

## Using the keyboard

### Layouts and keys

Aiboard reads `.ascconfig` packages from `~/Library/Application Support/com.apple.AssistiveControl`. Select a layout or reload edited profiles from the panel menu. When an app becomes active, Aiboard selects its associated panel. Use the language selector beside the suggestions to change keyboard language.

- Left-click types the primary key; right-click types its shifted action.
- Modifier keys latch for the next keystroke.
- Hold a key to repeat it. Drag away to stop.
- Caps Lock stays on until clicked again. While on, left-click types uppercase letters and right-click types lowercase. Numbers, punctuation, and shortcuts keep their usual actions.

### Window and visibility

The titlebar can hide the keyboard or collapse it to an expand button. Use the menu bar to show it again, open Settings, or quit. All layouts share the saved window width and position. The height adjusts to fit the keys. Settings controls the minimum scale.

Pause in the bottom-right 6-point corner of any display for 1.5 seconds to hide or show the keyboard. A countdown shows progress, and the keypress sound confirms the change. Leave the corner before triggering it again. Settings lets you change the delay from 0.5 to 5 seconds.

By default, the keyboard also hides after 15 seconds without pointer movement and returns when the pointer moves. You can disable this or set a delay from 5 to 120 seconds. Holding a mouse button pauses automatic hiding. Pointer movement won't reopen a keyboard hidden manually or through the hot corner.

### Function toolbar

The button beside the language selector shows a row of brightness, Mission Control, Spotlight, F5/F6, media, and volume controls. Latch Fn to switch to F1 through F12. Escape stays at the start of both rows.

The window resizes with the toolbar while keeping the main keys the same size. Reduce Motion makes this change immediate. Brightness depends on display support. Aiboard doesn't implement DDC for external displays. Media and volume controls follow macOS routing.

### Button sounds

Choose the default macOS key click, one of 13 mechanical-switch recordings, a custom audio file, or **None** in Settings. Aiboard checks imported audio and saves a copy in its Application Support directory.

Aiboard includes mechanical-switch samples from [tplai/kbsim](https://github.com/tplai/kbsim) under its MIT license. See the [source notes](Aiboard/Resources/KeyboardSounds/SOURCE-kbsim.md) and [license notice](Aiboard/Resources/KeyboardSounds/LICENSE-kbsim.txt).

### Startup and locked screens

Enable **Settings → Startup → Open Aiboard at login** to open the keyboard after signing in.

The separate [login-window installation](docs/login-window-keyboard.md) is designed to show the keyboard before sign-in and hand off to the normal app afterward. Pre-login visibility, input permission, and handoff still require a manual restart or logout test. It cannot appear on FileVault's preboot unlock screen.

Settings also has an opt-in [experimental lock-screen keyboard](docs/lock-screen-display.md). It uses private macOS APIs. Predictions and diagnostic text reads stay off while locked, and macOS may reject input at protected fields.

## Text prediction

macOS supplies ranked word completions and next-word suggestions in the selected keyboard language. After a 150 ms typing pause, on-device Foundation Models fills any remaining slots. If native results fill all eight slots, Aiboard skips model generation. Dictionary completion is a fallback for partial words. Results may differ from Apple's Accessibility Keyboard.

The suggestion row displays up to eight words, as space permits. The new part of each word is bold. Suggestions remain clickable while results refresh and stay in place while pressed.

Accepting a suggestion inserts the missing suffix or next word and adds a space at the end of the field. Punctuation typed immediately afterward removes that automatic space. A next-word suggestion after punctuation adds a leading space only if needed. Aiboard preserves spaces you type yourself. Moving the cursor or changing the field or earlier text cancels the spacing adjustment.

### Context and limits

The model receives the keyboard language, typed prefix, and up to 512 preceding characters. Text stays in memory. Prediction logs contain timings only. Aiboard rechecks focus and text before inserting a suggestion.

Predictions pause for selected text, a cursor inside a word, shortcut modifiers, and detected secure input. Hiding or minimizing the keyboard, or disabling predictions, stops observation and clears context. Empty context clears suggestions.

When Accessibility cannot read editable text and cursor data, Aiboard tracks up to 512 characters typed through its own keys. This buffer clears on detected focus changes, outside clicks, untracked typing, navigation, submission, editing shortcuts, input-source changes, and screen lock.

Dead-key composition pauses suggestions. Aiboard cannot reconstruct input methods without a Unicode keyboard layout.

Buffer-based suggestions only append text. They don't replace existing text or remove spaces before punctuation. The buffer records what Aiboard sent, so app-side corrections, ignored keys, text after the cursor, or undetected focus changes can make it inaccurate. Aiboard uses editable text from Accessibility instead whenever it can read it.

Settings shows whether Apple Intelligence is available. See [text prediction performance](docs/text-prediction-performance.md) for benchmarks and validation limits.

## Development

The app uses SwiftUI, AppKit, and the Observation framework. The build helper stops any running Aiboard instance, builds Debug by default, and writes output to `.build/DerivedData`.

```sh
./script/build_and_run.sh --debug      # Launch under LLDB
./script/build_and_run.sh --logs       # Launch and stream app logs
./script/build_and_run.sh --telemetry  # Launch and stream subsystem logs
./script/build_and_run.sh --verify     # Check that the app process launches
```

For a Release build, prefix the command with `AIBOARD_BUILD_CONFIGURATION=Release`.

Run unit tests without sending keyboard input to another app:

```sh
xcodebuild -project Aiboard.xcodeproj -scheme Aiboard \
  -destination 'platform=macOS' -derivedDataPath .build/DerivedData \
  -only-testing:AiboardTests test
```

UI tests use your local profiles and require a saved Panel Editor keyboard containing Shift keys, plus Accessibility permission. They don't test an isolated first-run setup.

## Releases

Aiboard includes Sparkle updates. Use **Check for Updates…** in the menu or Settings. When an automatic check finds an update, a blue download button appears to the left of the keyboard's accessibility icon. See [app updates](docs/app-updates.md) for signing, hosting, and verification details. Update checks will work once this repository is public and a stable release with an appcast is available.

Push a version tag to build and publish a [GitHub release](https://github.com/davutac/aiboard/releases):

```sh
git tag -a v1.0.0 -m "Aiboard 1.0.0"
git push origin v1.0.0
```

The [release workflow](.github/workflows/release.yml) accepts tags such as `v1.0.0` and `v1.1.0-beta.1`. Tags with a suffix create prereleases. It uses GitHub's `xcode-27` preview runner to archive an Apple Silicon Release build and verify its signature. Each release includes an APFS DMG with LZFSE compression, a Sparkle `appcast.xml` with the update signature, a debug-symbol archive, `SHA256SUMS.txt`, and generated release notes. The app version comes from the tag, and the build number comes from the workflow run number. Only stable releases are offered through the update feed.

The download requires macOS 27 or later. Open the DMG and drag `Aiboard.app` onto the Applications shortcut. Eject the disk image, open Aiboard from Applications, and grant Accessibility permission. The release workflow signs the app and DMG with Developer ID, notarizes both with Apple, and staples their tickets before generating the Sparkle feed. It requires the Apple signing credentials and Sparkle configuration described in [app updates](docs/app-updates.md). Releases published before this signing setup remain ad-hoc signed and may require approval in System Settings → Privacy & Security.

The runner has the macOS 27 SDK but runs macOS 26, so the release job builds and packages the app without launching it or running its tests. Run unit tests on macOS 27 before tagging a release.

## Documentation

- [App updates](docs/app-updates.md): Sparkle integration, release signing, update hosting, and verification.
- [Design system](docs/design-system.md): shared styling, colors, typography, and previews.
- [Text prediction performance](docs/text-prediction-performance.md): benchmarks, measurements, and validation limits.
- [Login-window keyboard](docs/login-window-keyboard.md): local package preparation, installation, removal, and manual pre-login checks.
- [Experimental lock-screen display](docs/lock-screen-display.md): setup and limitations for an existing locked session.

## Code organization

Source paths below are relative to `Aiboard/`.

- `DesignSystem`: colors, keycap styles, typography, spacing, and previews.
- `Features/Main`: the main window, status strip, and panel sizing.
- `Features/Settings`: the Settings scene.
- `Features/Suggestions`: word suggestion buttons and layout.
- `Features/LoginWindow`: pre-login startup, the saved home-keyboard snapshot, and session handoff.
- `Components/Keyboard`: panel layout, key rendering, actions, and pointer handling.
- `Components/AlwaysOnTopWindow`: floating AppKit panels and saved window geometry.
- `Models/PanelEditorProfile.swift`: imported profile, panel, and button types.
- `Services`: profile loading, Accessibility, input delivery, predictions, languages, and sound.
- `Models/KeyAction.swift` and `Enums/Keys.swift`: shared key actions, press behaviors, key codes, and modifiers.

Profile import reads Apple's undocumented format without modifying the source files. A broken package doesn't block other profiles. If a reload fails completely, Aiboard keeps the last working keyboard and shows a warning. A successful reload that finds no profiles clears the keyboard.
