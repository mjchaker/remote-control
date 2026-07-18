# MacRemote — Technical Design

## Overview

MacRemote is a native **macOS** SwiftUI application that turns the Mac it runs on into a gesture-driven media and system remote. Instead of talking to a separate device over the network, it **synthesizes macOS system events** — media keys, volume changes, arrow keys, scroll wheel, and AppleScript actions — so a large touch surface and a handful of buttons drive playback, volume, brightness, navigation, and screen lock on the local machine.

This document describes what is actually built. It is a proof of concept: a single, self-contained app with no networking, no device discovery, and no external dependencies.

> **Scope note.** An earlier draft of this document described a much larger "Universal Remote" that would control Apple TV, HomeKit/Matter accessories, and Bluetooth peripherals over Wi-Fi. That vision is **not implemented** and is not described here. What follows matches the code in `MacRemote/`. The networked, multi-protocol product remains a possible future direction, summarized briefly at the end.

---

## Mental model

The app is a thin, one-directional pipeline from user input to a synthesized OS event:

```
┌──────────────────────────────────────────────────────────────┐
│  UI layer (SwiftUI)                                            │
│   TouchSurfaceView   ──gesture──┐      RemoteControlView       │
│   (gesture surface)             │      (buttons, slider)       │
│                                 │              │               │
│                                 ▼              ▼               │
│                        UniversalCommand (enum, protocol-free)  │
├──────────────────────────────────────────────────────────────┤
│  Service layer                                                 │
│   MediaControlService.shared.execute(_:)   @MainActor          │
│         dispatches by command category                         │
├──────────────────────────────────────────────────────────────┤
│  macOS system APIs                                             │
│   NSEvent (systemDefined)  ·  CoreAudio  ·  CGEvent            │
│   NSAppleScript  ·  NSHapticFeedbackManager                    │
└──────────────────────────────────────────────────────────────┘
```

The UI never touches system APIs directly. It only builds a `UniversalCommand` and hands it to the service. This keeps gesture/button code declarative and puts every privileged operation in one file.

---

## Layer 1: The command model

`Models/Command.swift` defines the vocabulary of the app. `UniversalCommand` is a protocol-agnostic enum; each case wraps a category-specific action enum.

```swift
enum UniversalCommand: Equatable {
    case media(MediaAction)
    case volume(VolumeAction)
    case navigation(NavigationAction)
    case system(SystemAction)
}
```

The action enums:

| Enum | Cases | Notes |
|------|-------|-------|
| `MediaAction` | `playPause`, `next`, `previous`, `fastForward`, `rewind` | `String`-backed, `CaseIterable`; each has a `systemImageName` (SF Symbol) |
| `VolumeAction` | `up`, `down`, `mute`, `setLevel` | Same shape; `setLevel` is currently unimplemented (see rough edges) |
| `NavigationAction` | `up`, `down`, `left`, `right`, `select`, `back`, `scroll(dx:dy:)` | `Equatable` (carries scroll deltas); has a `description` string |
| `SystemAction` | `brightnessUp`, `brightnessDown`, `sleep`, `lock` | `String`-backed, `CaseIterable`, `systemImageName` |

**Design intent:** to add a new controllable action you add a case here, handle it in `MediaControlService`, and optionally surface it in the UI. The `rawValue` display string + `systemImageName` convention lets buttons render uniformly and lets the status line show a human-readable label for free.

---

## Layer 2: The control service

`Services/MediaControlService.swift` is the only place that calls system APIs. It is a `@MainActor`, `ObservableObject` **singleton** (`MediaControlService.shared`) that publishes UI state:

```swift
@Published var lastCommand: String = "Ready"
@Published var currentVolume: Float = 0.5
@Published var isMuted: Bool = false
```

Everything enters through one `async` method that dispatches by category:

```swift
func execute(_ command: UniversalCommand) async {
    switch command {
    case .media(let a):      await executeMediaAction(a)
    case .volume(let a):     await executeVolumeAction(a)
    case .navigation(let a): await executeNavigationAction(a)
    case .system(let a):     await executeSystemAction(a)
    }
}
```

### How each category reaches the OS

- **Media keys** (`play/pause`, `next`, `previous`, `fast-forward`, `rewind`) and **brightness** are sent as low-level HID media-key events. The service builds an `NSEvent.otherEvent(with: .systemDefined, …)` pair (key-down then key-up) using the private `NX_KEYTYPE_*` constants from Carbon, packs the key code into `data1`, sets the `0xa00`/`0xb00` modifier masks and subtype `8`, and posts each via `event.cgEvent?.post(tap: .cghidEventTap)`.

- **Volume and mute** go through **CoreAudio**. The service resolves the default output device (`kAudioHardwarePropertyDefaultOutputDevice`), then reads/writes `kAudioDevicePropertyVolumeScalar` (clamped to 0.0–1.0, ±0.05 per step) or toggles `kAudioDevicePropertyMute`. After a volume change it refreshes `currentVolume` from the system so the published state stays truthful.

- **Navigation** maps arrows/select/back to virtual key codes (up 126, down 125, left 123, right 124, return 36, delete 51) synthesized with `CGEvent(keyboardEventSource:virtualKey:keyDown:)`. `scroll(dx:dy:)` posts a pixel-unit `CGEvent(scrollWheelEvent2Source:…)`.

- **System** actions split: brightness reuses the media-key path; `sleep` and `lock` run **AppleScript** via `NSAppleScript` (`tell application "System Events" to sleep`, and a `⌃⌘Q` keystroke to lock).

Every handler sets `lastCommand` to a display string so the UI status line reflects the most recent action.

---

## Layer 3: Gesture recognition

`Views/TouchSurfaceView.swift` turns raw drag data into a discrete gesture, then into a command. It uses a single `DragGesture(minimumDistance: 0)` and tracks progress in a `GestureState`.

### Supporting types (`Models/GestureType.swift`)

- **`GestureType`** — the recognized gesture: `tap`, `longPress`, `swipeUp/Down/Left/Right`, `scroll(dx:dy:)`, `none`. Carries a `description` for display.
- **`GestureConfiguration`** — tunable thresholds:

  | Field | Default | Meaning |
  |-------|---------|---------|
  | `swipeThreshold` | 50.0 pt | minimum distance to count as a swipe |
  | `longPressDuration` | 0.5 s | hold time for a long press |
  | `tapMaxMovement` | 10.0 pt | max drift still counted as a tap |
  | `swipeVelocityThreshold` | 300.0 pt/s | swipe-vs-scroll velocity cutoff |
  | `scrollSensitivity` | 1.0 | scroll delta multiplier |

- **`GestureState`** — mutable per-drag record (`startLocation`, `currentLocation`, `startTime`, `isActive`) with computed `translation`, `distance`, `duration`, and `velocity`, plus `reset()`.

### Classification (`recognizeGesture`)

On gesture end, the surface classifies in priority order:

1. **Long press** — `distance < tapMaxMovement` **and** `duration > longPressDuration`
2. **Tap** — `distance < tapMaxMovement` (short)
3. **Swipe** — total velocity `> swipeVelocityThreshold`; dominant axis and sign choose the direction
4. **Scroll** — anything else (low-velocity drag), carrying the raw translation as deltas

### Gesture → command mapping (`executeGesture`)

| Gesture | Command |
|---------|---------|
| Tap | `.media(.playPause)` |
| Long press | `.navigation(.back)` |
| Swipe up | `.volume(.up)` |
| Swipe down | `.volume(.down)` |
| Swipe left | `.media(.previous)` |
| Swipe right | `.media(.next)` |
| Scroll | `.navigation(.scroll(dx: dx*0.5, dy: dy*0.5))` |

The surface also gives live visual feedback (a press indicator, the gesture label, and Δx/Δy readouts) and fires `HapticEngine.shared.selection()` on release.

---

## Layer 4: UI composition

- **`App/MacRemoteApp.swift`** — `@main` SwiftUI `App`; a single `WindowGroup` with a hidden title bar and content-sized window.
- **`Views/ContentView.swift`** — root view; wraps `RemoteControlView` and pins the window size (≈400–500 × 800–1000).
- **`Views/RemoteControlView.swift`** — the full remote: header, the touch surface, a volume slider + mute, media buttons (previous / play-pause / next), system buttons (dim / bright / lock), and a status line bound to `mediaService.lastCommand`. Buttons construct commands and call the service inside `Task { await … }`, with `HapticEngine.shared.light()` on press.
- **`Utilities/HapticEngine.swift`** — singleton over `NSHapticFeedbackManager.defaultPerformer` exposing `light/medium/heavy/selection/success/error` (trackpad haptics only).

---

## Platform, build, and permissions

- **Language / UI:** Swift 5.0, SwiftUI.
- **Deployment target:** macOS 13.0 (`MACOSX_DEPLOYMENT_TARGET = 13.0`).
- **Bundle identifier:** `com.example.MacRemote`. `Info.plist` is checked in (`GENERATE_INFOPLIST_FILE = NO`); category is Utilities.
- **Frameworks:** AppKit, CoreAudio, Carbon, CoreGraphics (`CGEvent`) — no third-party dependencies, no package manager, no test target, no CI.
- **Build:** open `MacRemote/MacRemote.xcodeproj` in Xcode and Run (⌘R), or `xcodebuild -project MacRemote/MacRemote.xcodeproj -scheme MacRemote build` on a Mac with Xcode.

### Runtime permissions

- **Accessibility** (System Settings → Privacy & Security → Accessibility) — required for synthesized key/scroll HID events to be delivered.
- **Automation / Apple Events** — required for `sleep` and `lock`, which drive System Events via AppleScript.

### Sandbox tension (known)

`MacRemote.entitlements` enables **App Sandbox** (`com.apple.security.app-sandbox`) along with `com.apple.security.automation.apple-events` and user-selected read-only file access. Synthesizing global HID events and driving System Events generally depends on Accessibility permission and can conflict with a strict sandbox. This tension is unresolved in the proof of concept; any change touching distribution, entitlements, or event delivery should treat it deliberately rather than flipping the sandbox flag silently, since it affects the app's security posture.

---

## Known rough edges

These are current limitations, not intentional design:

- **Volume slider is not absolute.** `VolumeAction.setLevel` exists but is a no-op (`break`) in the service, and the slider in `RemoteControlView` is wired so that dragging it simply issues `.volume(.up)`. A proper implementation needs a `setLevel(Float)` path from the slider through `UniversalCommand` into a CoreAudio absolute-volume write.
- **Private media-key event synthesis is fragile.** The `NX_KEYTYPE_*` constants and the specific `NSEvent` subtype/modifier-mask packing are undocumented; behavior can change across macOS versions, so test on-device after edits.
- **Volume state can drift.** `currentVolume`/`isMuted` are refreshed after the app's own writes, but nothing observes external system volume changes, so the slider may lag the true system volume until the next command.
- **macOS only.** Despite the parent repo's iPhone/iPad framing, this target is a Mac app controlling the Mac it runs on.

---

## Possible future direction

The original ambition — a *networked* universal remote that discovers and controls Apple TV (MediaRemote), HomeKit/Matter accessories, and Bluetooth LE devices over Wi-Fi — would reuse the one abstraction that already exists here: `UniversalCommand`. The natural extension is a **protocol-translator layer** behind the service, where each transport (HomeKit, MediaRemote, BLE) implements a translator from `UniversalCommand` to its wire format, and the current local-event path becomes just one translator among several. None of that is built today; MacRemote deliberately stays a single-file-per-concern, local-only proof of concept.
