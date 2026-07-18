# CLAUDE.md — Remote Control

Guidance for AI assistants working in this repository. Read this first, then the file(s) relevant to your task.

## What this repository actually contains

Two things live here, and it's important not to confuse them:

1. **`MacRemote/`** — a **working macOS SwiftUI proof of concept**. This is the only code that exists and builds. It turns the local Mac into a gesture-controlled media/system remote by synthesizing system events. It controls **the Mac it runs on**, not a separate device over the network.

2. **`DESIGN.md`** — a **forward-looking product vision** for a much larger "Universal Remote" app that would control Apple TV, HomeKit/Matter accessories, and other devices over Wi-Fi/Bluetooth. **None of this is implemented.** The Swift snippets in `DESIGN.md` are conceptual illustrations, not real files. Treat it as a design draft, not a spec of current behavior.

When a task references "the app," assume it means `MacRemote/` unless the user explicitly points at the DESIGN.md vision. Don't document or reason about the `UniversalRemote/`, `Core/Protocols/`, `HomeKitBridge`, `MediaRemoteBridge`, etc. structures from DESIGN.md as if they exist — they don't.

## Repository layout

```
remote-control/
├── CLAUDE.MD                 # This file
├── README.md                 # One-paragraph product pitch (aspirational)
├── DESIGN.md                 # Full product vision / design draft (NOT implemented)
├── LICENSE                   # MIT
└── MacRemote/                # The actual, buildable macOS app (proof of concept)
    ├── README.md             # MacRemote-specific docs, gestures, troubleshooting
    ├── MacRemote.xcodeproj/
    └── MacRemote/
        ├── App/
        │   └── MacRemoteApp.swift         # @main entry point (SwiftUI App)
        ├── Models/
        │   ├── Command.swift              # UniversalCommand enum + action enums
        │   └── GestureType.swift          # GestureType, GestureConfiguration, GestureState
        ├── Services/
        │   └── MediaControlService.swift  # Executes commands on the local Mac (the core)
        ├── Views/
        │   ├── ContentView.swift          # Root view, sets window sizing
        │   ├── RemoteControlView.swift    # Full UI: touch surface + buttons + status
        │   └── TouchSurfaceView.swift     # Gesture recognition surface
        ├── Utilities/
        │   └── HapticEngine.swift         # Trackpad haptic feedback wrapper
        ├── Assets.xcassets/
        ├── Info.plist
        └── MacRemote.entitlements
```

## Tech stack (MacRemote)

- **Language**: Swift 5.0 (`SWIFT_VERSION = 5.0` in the project)
- **UI**: SwiftUI (macOS app, `WindowGroup`, hidden title bar, content-sized window)
- **Deployment target**: macOS 13.0 (`MACOSX_DEPLOYMENT_TARGET = 13.0`)
- **Bundle ID**: `com.example.MacRemote`
- **Info.plist**: checked-in file, `GENERATE_INFOPLIST_FILE = NO`
- **Apple frameworks in use**:
  - `AppKit` — `NSEvent` system-defined events, `NSAppleScript`, `NSHapticFeedbackManager`
  - `CoreAudio` — reading/writing system output volume and mute
  - `Carbon` — media/brightness key constants (`NX_KEYTYPE_*`)
  - `CoreGraphics` (`CGEvent`) — synthesizing key presses and scroll events

Note: the frameworks named in the top-level README/DESIGN.md (`HomeKit`, `MediaRemote`, `CoreBluetooth`, `AirPlay`, `Combine`) are **not** used by MacRemote.

## Architecture (MacRemote)

The flow is a small, clean pipeline:

```
User input (gesture on TouchSurfaceView, or button in RemoteControlView)
        ↓
UniversalCommand  (Models/Command.swift — protocol-agnostic command enum)
        ↓
MediaControlService.execute(_:)  (Services/MediaControlService.swift)
        ↓
Synthesized macOS system event (NSEvent / CGEvent / CoreAudio / AppleScript)
```

Key pieces:

- **`UniversalCommand`** (`Command.swift`) is the central abstraction — a Swift enum with cases `.media`, `.volume`, `.navigation`, `.system`, each wrapping a more specific action enum (`MediaAction`, `VolumeAction`, `NavigationAction`, `SystemAction`). The UI never talks to system APIs directly; it only constructs `UniversalCommand` values. This is the one piece of the DESIGN.md "bridge pattern" that actually exists.

- **`MediaControlService`** (`Services/MediaControlService.swift`) is a `@MainActor`, `ObservableObject` **singleton** (`MediaControlService.shared`). It is the only place that touches system APIs. It publishes `lastCommand`, `currentVolume`, and `isMuted` for the UI. All command execution goes through `execute(_ command:)`, which dispatches to private per-category handlers.
  - Media/brightness keys: synthesized via `NSEvent.otherEvent(with: .systemDefined, ...)` posted as `.cghidEventTap`.
  - Volume/mute: read/written through `CoreAudio` (`AudioObjectGetPropertyData`/`SetPropertyData`) on the default output device.
  - Navigation (arrows/return/delete) and scroll: `CGEvent` keyboard and scroll-wheel events.
  - Sleep and lock: `NSAppleScript` driving System Events.

- **`TouchSurfaceView`** (`Views/TouchSurfaceView.swift`) owns gesture recognition. A single `DragGesture(minimumDistance: 0)` feeds `GestureState`; on gesture end, `recognizeGesture()` classifies it (tap / long press / directional swipe / scroll) using thresholds from `GestureConfiguration`, then `executeGesture(_:)` maps the gesture to a `UniversalCommand` and calls the service.

- **`RemoteControlView`** (`Views/RemoteControlView.swift`) is the full UI: header, touch surface, volume slider + mute, media buttons, system buttons, and a status line bound to `mediaService.lastCommand`.

- **`HapticEngine`** (`Utilities/HapticEngine.swift`) is a singleton wrapping `NSHapticFeedbackManager` (trackpad haptics only).

### Gesture → command mapping (current defaults)

Defined in `TouchSurfaceView.executeGesture(_:)`:

| Gesture      | Command                        |
|--------------|--------------------------------|
| Tap          | `.media(.playPause)`           |
| Long press   | `.navigation(.back)`           |
| Swipe up     | `.volume(.up)`                 |
| Swipe down   | `.volume(.down)`               |
| Swipe left   | `.media(.previous)`            |
| Swipe right  | `.media(.next)`                |
| Scroll       | `.navigation(.scroll(dx,dy))`  |

Recognition thresholds live in `GestureConfiguration` (`GestureType.swift`): `swipeThreshold` 50pt, `longPressDuration` 0.5s, `tapMaxMovement` 10pt, `swipeVelocityThreshold` 300pt/s, `scrollSensitivity` 1.0.

## Building and running

There is **no CI, no test target, no linter config, and no package manager** in this repo. It is a plain Xcode project.

```bash
open MacRemote/MacRemote.xcodeproj   # then Build & Run (⌘R) in Xcode
```

Command-line build (requires a macOS machine with Xcode):

```bash
xcodebuild -project MacRemote/MacRemote.xcodeproj -scheme MacRemote -configuration Debug build
```

There are no automated tests to run. "Verifying" a change means building in Xcode and exercising the affected control by hand.

### Runtime permissions

On first launch macOS prompts for:
- **Accessibility** (System Settings → Privacy & Security → Accessibility) — required for synthesized key/scroll events to reach the system.
- **Automation / Apple Events** — required for sleep and lock (AppleScript to System Events).

### Known constraint worth flagging

The entitlements file (`MacRemote.entitlements`) enables **App Sandbox** (`com.apple.security.app-sandbox = true`) plus `apple-events` and user-selected read-only file access. Synthesizing global HID events and driving System Events generally requires Accessibility permission and often conflicts with a strict sandbox. If a task involves distribution, event delivery not working, or entitlement changes, don't silently "fix" the sandbox — surface the tension and confirm the intended direction with the user first, since it affects the app's security posture.

## Conventions for making changes

- **Route everything through `UniversalCommand`.** UI code (views, buttons, gestures) must construct a `UniversalCommand` and call `MediaControlService.shared.execute(_:)`. Do not call `CGEvent`, `CoreAudio`, `NSAppleScript`, etc. from a view. To add a capability: add a case to the appropriate action enum in `Command.swift`, handle it in the matching `execute…Action` method in `MediaControlService.swift`, then wire up UI/gesture triggers.
- **`MediaControlService` is `@MainActor` and a singleton.** Access it as `MediaControlService.shared`. Its `execute(_:)` is `async`; call it inside a `Task { await … }`.
- **Adding an action enum case** that conforms to `CaseIterable` with a `rawValue` display string and a `systemImageName` (SF Symbol) keeps it consistent with existing `MediaAction`/`VolumeAction`/`SystemAction` and lets the UI render it uniformly.
- **Style**: SwiftUI throughout; `async/await` (not completion handlers); file header comment blocks in the existing `//  Name.swift` style; SF Symbols for iconography; each view file ends with a `#Preview`.
- **Haptics**: use `HapticEngine.shared` for feedback on interactions, matching existing calls (`.selection()` on gesture end, `.light()` on button press).

### Known rough edges (don't treat as intentional)

- The volume `Slider` in `RemoteControlView` is bound such that dragging it just calls `.volume(.up)` — it does not set an absolute level. `VolumeAction.setLevel` exists but is a no-op (`break`) in the service. A real slider needs a `setLevel(Float)` path through the command/service.
- Media/brightness key synthesis relies on private `NX_KEYTYPE_*` constants and specific `NSEvent` subtypes/modifier masks; treat these as fragile and test on-device after changes.

## Git / workflow notes

- Default branch is `main`. Do development on the feature branch you were assigned; commit with clear messages and push there.
- Do **not** open a pull request unless the user explicitly asks.
- History shows the repo started as docs-only (README/DESIGN/LICENSE) and the MacRemote proof of concept was added later — keep CLAUDE.MD in sync with the code as the app grows, and correct any place where docs drift back toward describing the unbuilt DESIGN.md vision as if it were real.

## Quick reference: where things live

| I want to…                              | Go to |
|-----------------------------------------|-------|
| Add a new controllable action           | `Models/Command.swift` + `Services/MediaControlService.swift` |
| Change how a gesture is classified      | `Views/TouchSurfaceView.swift` (`recognizeGesture`) + `Models/GestureType.swift` (`GestureConfiguration`) |
| Change what a gesture does              | `Views/TouchSurfaceView.swift` (`executeGesture`) |
| Change the UI / buttons / layout        | `Views/RemoteControlView.swift` |
| Change system-event synthesis           | `Services/MediaControlService.swift` |
| Change haptic behavior                  | `Utilities/HapticEngine.swift` |
| Change window size / app entry          | `Views/ContentView.swift`, `App/MacRemoteApp.swift` |
| Understand the (unbuilt) larger vision  | `DESIGN.md` |

---

**Target platform**: macOS 13.0+ · **Status**: working proof of concept (single-Mac control), broader networked "universal remote" vision unimplemented.
