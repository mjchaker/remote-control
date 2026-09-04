# CLAUDE.md — Remote Control

Guidance for AI assistants working in this repository. Read this first, then the file(s) relevant to your task.

## What this repository actually contains

1. **`MacRemote/`** — a **macOS SwiftUI app** with a unit-test target. It turns the local Mac into a gesture-controlled media/system remote by synthesizing system events. It controls **the Mac it runs on**, not a separate device over the network.

2. **`DESIGN.md`** — the technical design of that app. Its closing section mentions a *possible* future "Universal Remote" (Apple TV, HomeKit/Matter, Bluetooth). **None of that is implemented.** Don't document or reason about `UniversalRemote/`, `Core/Protocols/`, `HomeKitBridge`, `MediaRemoteBridge`, etc. as if they exist — they don't.

When a task references "the app," it means `MacRemote/`.

## Repository layout

```
remote-control/
├── CLAUDE.MD                 # This file
├── README.md                 # Product overview, build/test, permissions
├── DESIGN.md                 # Technical design of the implementation
├── LICENSE                   # MIT
├── .github/workflows/ci.yml  # GitHub Actions: xcodebuild build + test on macOS
└── MacRemote/
    ├── README.md             # Usage, gestures, settings, troubleshooting
    ├── MacRemote.xcodeproj/  # Shared scheme "MacRemote" in xcshareddata/
    ├── MacRemote/
    │   ├── App/MacRemoteApp.swift                  # @main: WindowGroup, Controls menu, Settings, MenuBarExtra
    │   ├── Models/
    │   │   ├── Command.swift                       # UniversalCommand + action enums
    │   │   ├── GestureType.swift                   # GestureType, GestureConfiguration (+Limits, clamped), GestureState
    │   │   ├── GestureRecognizer.swift             # PURE classify() + command(for:) — unit tested
    │   │   └── AppSettings.swift                   # Persisted preferences (UserDefaults), @MainActor singleton
    │   ├── Services/
    │   │   ├── MediaControlService.swift           # The only file that touches system APIs
    │   │   └── AccessibilityPermission.swift       # Publishes isTrusted; polls until granted
    │   ├── Views/
    │   │   ├── ContentView.swift                   # Root view, window sizing
    │   │   ├── RemoteControlView.swift             # Banner + surface + controls + status line
    │   │   ├── TouchSurfaceView.swift              # Collects drag, delegates to GestureRecognizer
    │   │   ├── SettingsView.swift                  # Settings window (⌘,)
    │   │   └── MenuBarView.swift                   # MenuBarExtra contents
    │   ├── Utilities/HapticEngine.swift            # Haptics, honours AppSettings.hapticsEnabled
    │   ├── Assets.xcassets/                        # AccentColor + (empty) AppIcon set
    │   ├── Info.plist                              # includes NSAppleEventsUsageDescription
    │   └── MacRemote.entitlements                  # App Sandbox + Apple-events exception for System Events
    └── MacRemoteTests/
        ├── GestureRecognizerTests.swift
        ├── AppSettingsTests.swift
        └── CommandTests.swift
```

## Tech stack

- **Language**: Swift 5.0 (`SWIFT_VERSION = 5.0`), SwiftUI, `async/await`, `@MainActor` singletons.
- **Deployment target**: macOS 13.0. Bundle ID `com.example.MacRemote` (placeholder — change before distribution).
- **Frameworks**: AppKit, ApplicationServices (`AXIsProcessTrusted`), CoreAudio (volume + property listeners), Carbon (`NX_KEYTYPE_*`, `kVK_*`), CoreGraphics (`CGEvent`), os (`Logger`), XCTest.
- **Build settings of note**: `GENERATE_INFOPLIST_FILE = NO` (app), `ENABLE_HARDENED_RUNTIME = YES`, App Sandbox on. The test target is app-hosted (`TEST_HOST`/`BUNDLE_LOADER`) and uses `@testable import MacRemote`.
- No package manager, no third-party dependencies, no linter config.

## Architecture

```
Input (gesture / button / menu / menu bar extra)
   ↓
UniversalCommand                      (Models/Command.swift)
   ↓
MediaControlService.execute(_:)       (@MainActor singleton; clears lastError, dispatches)
   ↓
NSEvent / CGEvent / CoreAudio / NSAppleScript
   ↑ feedback: lastCommand, currentVolume, isMuted (live via CoreAudio listeners), lastError
```

Key pieces:

- **`UniversalCommand`** is the central abstraction. The UI never talks to system APIs; it only constructs commands.
- **`MediaControlService`** is the only place that touches system APIs. It publishes `lastCommand`, `currentVolume`, `isMuted`, `lastError`. Every HID-posting path calls `requireAccessibility()` first and reports a precise message if the app isn't trusted. Volume reads/writes fall back from the master element to per-channel elements. Lock is a ⌃⌘Q `CGEvent`; sleep is the only AppleScript action.
- **`GestureRecognizer.classify`** is a pure function of `(translation, duration, configuration)`; `TouchSurfaceView` only collects the drag and calls it on release. Keep it pure — it's what the tests cover.
- **`AppSettings`** owns thresholds and toggles, persisted to `UserDefaults` and clamped to `GestureConfiguration.Limits` on load and store. Inject a `UserDefaults` suite in tests.
- **`AccessibilityPermission`** publishes `isTrusted`; `RemoteControlView` shows a banner with "Open System Settings" until it's true.

### Gesture → command mapping (`GestureRecognizer.command(for:)`)

| Gesture      | Command                          |
|--------------|----------------------------------|
| Tap          | `.media(.playPause)`             |
| Long press   | `.navigation(.back)`             |
| Swipe up     | `.volume(.up)`                   |
| Swipe down   | `.volume(.down)`                 |
| Swipe left   | `.media(.previous)`              |
| Swipe right  | `.media(.next)`                  |
| Scroll       | `.navigation(.scroll(dx/2,dy/2))`|

Defaults: `tapMaxMovement` 10pt, `longPressDuration` 0.5s, `swipeThreshold` 50pt, `swipeVelocityThreshold` 300pt/s, `scrollSensitivity` 1.0. Users edit these in Settings; tests pin the classifier's behaviour at the boundaries.

## Building, testing, CI

```bash
open MacRemote/MacRemote.xcodeproj    # ⌘R to run, ⌘U to test
xcodebuild -project MacRemote/MacRemote.xcodeproj -scheme MacRemote -destination 'platform=macOS' build
xcodebuild -project MacRemote/MacRemote.xcodeproj -scheme MacRemote -destination 'platform=macOS' test
```

`.github/workflows/ci.yml` runs both on a macOS runner (`CODE_SIGNING_ALLOWED=NO`) for every push and PR. **If you are working from a non-macOS environment you cannot compile here — push and read the CI result, then fix.** Do not claim a build passes without CI or Xcode evidence.

Unit tests cover only the pure logic (classifier, settings, command vocabulary). Anything that posts events must be exercised by hand on a Mac with Accessibility granted.

### Runtime permissions

- **Accessibility** — required for all synthesized events. The app detects, explains, and links to the setting; polling stops once granted.
- **Automation / Apple Events** — required only for Sleep. `Info.plist` must keep `NSAppleEventsUsageDescription`, and the entitlements must keep the `temporary-exception.apple-events` entry for `com.apple.systemevents`, or the call fails silently.

### Sandbox posture (deliberate)

App Sandbox stays **on** with exactly the Apple-events entitlements the sleep command needs. Don't flip the sandbox flag or add entitlements without surfacing the trade-off to the user first; it changes the app's security posture and distribution options.

## Conventions for making changes

- **Route everything through `UniversalCommand`.** Views, menus, and the menu bar extra construct a command and call `MediaControlService.shared.execute(_:)` inside `Task { await … }`. Never call `CGEvent`, `CoreAudio`, `NSAppleScript`, or `AXIsProcessTrusted` from a view.
- **To add an action**: add the enum case in `Command.swift` (follow the `String`-backed/`CaseIterable` pattern unless it needs an associated value), handle it in the matching `execute…Action` in `MediaControlService.swift` (call `requireAccessibility()` before posting HID events; call `report(_:)` on any detectable failure), add a button and/or `Controls` menu item with a shortcut, and extend `CommandTests` if you added a display string.
- **To change gesture behaviour**: edit `GestureRecognizer` (and its tests), not `TouchSurfaceView`. New thresholds go in `GestureConfiguration` + `Limits`, get a slider in `SettingsView`, and a round-trip test in `AppSettingsTests`.
- **Errors are UI state, not console noise.** Use `report(_:)` (logs via `os.Logger` and sets `lastError`), never bare `print`.
- **Observed singletons** are referenced with `@ObservedObject` (not `@StateObject`) since the view doesn't own them.
- **Style**: SwiftUI throughout; file header comment blocks in the existing `//  Name.swift` style; SF Symbols; each view file ends with a `#Preview`; semantic colors/fonts; `.help(_:)` + accessibility modifiers on interactive views; `HapticEngine.shared.light()` on button press, `.selection()` on gesture end.
- **Project file**: `project.pbxproj` uses short IDs (`A1xxxx` build files, `A2xxxx` file refs, `A5xxxx` groups, `A6xxxx` targets, `A8xxxx` phases, `ABxxxx` configs). When adding a Swift file, add a `PBXFileReference`, a `PBXBuildFile`, the group entry, and the Sources-phase entry — for the right target.

### Known rough edges (don't treat as intentional)

- Media/brightness key synthesis relies on private `NX_KEYTYPE_*` constants and specific `NSEvent` subtypes/masks; treat as fragile and test on-device after changes.
- Lock assumes the default ⌃⌘Q system shortcut.
- Scroll is emitted once on release (whole-drag delta), not continuously.
- No app icon artwork yet (the icon set exists but is empty).

## Git / workflow notes

- Default branch is `main`. Develop on the assigned feature branch; commit with clear messages and push there. Do **not** open a pull request unless the user explicitly asks.
- Keep this file, `README.md`, `MacRemote/README.md`, and `DESIGN.md` in sync with the code, and correct any drift toward describing the unbuilt networked vision as real.

## Quick reference: where things live

| I want to…                              | Go to |
|-----------------------------------------|-------|
| Add a new controllable action           | `Models/Command.swift` + `Services/MediaControlService.swift` + `App/MacRemoteApp.swift` (menu) |
| Change how a gesture is classified      | `Models/GestureRecognizer.swift` + `MacRemoteTests/GestureRecognizerTests.swift` |
| Change what a gesture does              | `GestureRecognizer.command(for:)` |
| Add/adjust a user preference            | `Models/AppSettings.swift` + `Views/SettingsView.swift` + `AppSettingsTests` |
| Change the UI / buttons / layout        | `Views/RemoteControlView.swift` |
| Change the menu bar extra               | `Views/MenuBarView.swift`, `App/MacRemoteApp.swift` |
| Change permission handling              | `Services/AccessibilityPermission.swift`, `requireAccessibility()` in the service |
| Change system-event synthesis           | `Services/MediaControlService.swift` |
| Change CI                               | `.github/workflows/ci.yml` |
| Understand the (unbuilt) larger vision  | end of `DESIGN.md` |

---

**Target platform**: macOS 13.0+ · **Status**: local single-Mac remote with tests and CI; networked "universal remote" vision unimplemented.
