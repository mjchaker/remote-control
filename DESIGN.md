# MacRemote — Technical Design

## Overview

MacRemote is a native **macOS** SwiftUI application that turns the Mac it runs on into a gesture-driven media and system remote. Instead of talking to a separate device over the network, it **synthesizes macOS system events** — media keys, volume changes, arrow keys, scroll wheel, modifier shortcuts, and one AppleScript action — so a large touch surface, a set of buttons, a menu bar extra, and keyboard shortcuts drive playback, volume, brightness, navigation, sleep, and screen lock on the local machine.

This document describes what is actually built: a single, self-contained app with no networking, no device discovery, and no external dependencies, plus a unit-test target and a CI workflow that builds and tests it on every push.

> **Scope note.** An earlier draft of this document described a much larger "Universal Remote" that would control Apple TV, HomeKit/Matter accessories, and Bluetooth peripherals over Wi-Fi. That vision is **not implemented** and is not described here. What follows matches the code in `MacRemote/`. The networked, multi-protocol product remains a possible future direction, summarized briefly at the end.

---

## Mental model

The app is a thin, one-directional pipeline from user input to a synthesized OS event, with two small side-channels feeding state back to the UI:

```
┌──────────────────────────────────────────────────────────────────────┐
│  UI layer (SwiftUI)                                                    │
│   TouchSurfaceView ─drag─▶ GestureRecognizer (pure) ─▶ UniversalCommand│
│   RemoteControlView / MenuBarView / Controls menu ──▶ UniversalCommand │
│   SettingsView ◀──▶ AppSettings (persisted thresholds & toggles)       │
├──────────────────────────────────────────────────────────────────────┤
│  Service layer (@MainActor singletons)                                 │
│   MediaControlService.execute(_:)  ── dispatch by command category     │
│       publishes lastCommand · currentVolume · isMuted · lastError      │
│   AccessibilityPermission ── publishes isTrusted (polls until granted) │
├──────────────────────────────────────────────────────────────────────┤
│  macOS system APIs                                                     │
│   NSEvent (systemDefined) · CGEvent · CoreAudio (+ listeners)          │
│   AXIsProcessTrusted · NSAppleScript · NSHapticFeedbackManager         │
└──────────────────────────────────────────────────────────────────────┘
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

| Enum | Cases | Notes |
|------|-------|-------|
| `MediaAction` | `playPause`, `next`, `previous`, `fastForward`, `rewind` | `String`-backed, `CaseIterable`; each has a `systemImageName` (SF Symbol) |
| `VolumeAction` | `up`, `down`, `mute`, `setLevel(Float)` | Plain `Equatable` enum (carries an absolute 0.0–1.0 level); exposes `displayName` + `systemImageName` |
| `NavigationAction` | `up`, `down`, `left`, `right`, `select`, `back`, `scroll(dx:dy:)` | `Equatable` (carries scroll deltas); has a `description` string |
| `SystemAction` | `brightnessUp`, `brightnessDown`, `sleep`, `lock` | `String`-backed, `CaseIterable`, `systemImageName` |

**Design intent:** to add a new controllable action you add a case here, handle it in `MediaControlService`, and surface it in the UI and the Controls menu. `CommandTests` asserts every case has a display string and symbol.

---

## Layer 2: The control service

`Services/MediaControlService.swift` is the only place that calls system APIs. It is a `@MainActor`, `ObservableObject` **singleton** (`MediaControlService.shared`) that publishes UI state:

```swift
@Published var lastCommand: String = "Ready"
@Published var currentVolume: Float = 0.5
@Published var isMuted: Bool = false
@Published var lastError: String?
```

Everything enters through one `async` method that clears `lastError` and dispatches by category. Handlers set `lastCommand` to the display string and, on any failure they can detect, call `report(_:)`, which logs through `os.Logger` and sets `lastError` so the status line can show it.

### How each category reaches the OS

- **Media keys** (`play/pause`, `next`, `previous`, `fast-forward`, `rewind`) and **brightness** share `sendSystemDefinedKey(_:)`. It builds an `NSEvent.otherEvent(with: .systemDefined, …)` pair (key-down then key-up) using the private `NX_KEYTYPE_*` constants from Carbon, packs the key code into `data1`, sets the `0xa00`/`0xb00` modifier masks and subtype `8`, and posts each via `cgEvent.post(tap: .cghidEventTap)`.

- **Volume and mute** go through **CoreAudio**. `controlElements(for:on:)` asks whether the default output device exposes the property on the main (master) element and, if not, falls back to the individual stereo channels — many USB/HDMI outputs only publish per-channel controls. `up`/`down` adjust by ±0.05, `setLevel(Float)` writes an absolute level (both clamped to 0.0–1.0), and setting a positive level while muted also unmutes. If a device offers neither element, the service reports "does not allow volume control" instead of silently doing nothing.

  **Live tracking.** On init the service registers `AudioObjectAddPropertyListenerBlock` listeners for the default-device property on the system object and for volume/mute on the current device. External changes (hardware keys, other apps, plugging in headphones) therefore update `currentVolume`/`isMuted` immediately, and listeners are re-attached when the default device changes.

- **Navigation** maps arrows/select/back to Carbon `kVK_*` virtual key codes synthesized with `CGEvent(keyboardEventSource:virtualKey:keyDown:)` from a `.hidSystemState` source. `scroll(dx:dy:)` posts a pixel-unit `CGEvent(scrollWheelEvent2Source:…)`.

- **System** actions split: brightness reuses the media-key path; **lock** posts the system-wide ⌃⌘Q shortcut as a `CGEvent` with `.maskCommand | .maskControl` (so it needs only Accessibility, not Automation); **sleep** runs `tell application "System Events" to sleep` via `NSAppleScript`, the one remaining Apple-events dependency. AppleScript errors are decoded — `-1743` becomes an "Automation access is required" message.

### Accessibility gate

Every HID-posting path first calls `requireAccessibility()`, which checks `AXIsProcessTrusted()` and reports a precise, actionable message when the app is not trusted. Without this, macOS drops synthesized events with no error at all.

---

## Layer 3: Gesture recognition

Recognition is split into a stateful collector and a pure classifier.

### Supporting types (`Models/GestureType.swift`)

- **`GestureType`** — the recognized gesture: `tap`, `longPress`, `swipeUp/Down/Left/Right`, `scroll(dx:dy:)`, `none`. Carries a `description` for display.
- **`GestureConfiguration`** — a value type of tunable thresholds with a `static default`, a `Limits` namespace giving the legal range of each field, and `clamped()`:

  | Field | Default | Meaning |
  |-------|---------|---------|
  | `tapMaxMovement` | 10 pt | max drift still counted as a tap / long press |
  | `longPressDuration` | 0.5 s | hold time for a long press |
  | `swipeThreshold` | 50 pt | minimum distance for a swipe |
  | `swipeVelocityThreshold` | 300 pt/s | swipe-vs-scroll speed cutoff |
  | `scrollSensitivity` | 1.0× | multiplier on drag translation |

- **`GestureState`** — mutable per-drag record (`startLocation`, `currentLocation`, `startTime`, `isActive`) with computed `translation`, `distance`, `duration`, and `velocity`, plus `reset()`.

### Classification (`Models/GestureRecognizer.swift`)

`GestureRecognizer.classify(translation:duration:configuration:)` is a **pure function** — same inputs, same output, no hidden state — which is what makes it unit-testable. Priority order:

1. **Long press** — `distance < tapMaxMovement` **and** `duration > longPressDuration`
2. **Tap** — `distance < tapMaxMovement`
3. **Swipe** — average speed `> swipeVelocityThreshold` **and** `distance >= swipeThreshold`; dominant axis and sign choose the direction
4. **Scroll** — anything else, carrying the translation as deltas

`GestureRecognizer.command(for:)` maps a gesture to its `UniversalCommand` (scroll deltas are halved). `GestureRecognizerTests` covers every branch, the boundary conditions, a zero-duration input, and the mapping table.

### The surface (`Views/TouchSurfaceView.swift`)

A single `DragGesture(minimumDistance: 0)` fills a `GestureState`. On release the view scales the translation by `scrollSensitivity`, calls `classify`, shows the result, dispatches the mapped command, resets, and fires `HapticEngine.shared.selection()`. Thresholds come from `AppSettings.shared.configuration`, so changes in Settings apply immediately.

### Persisted settings (`Models/AppSettings.swift`)

`AppSettings` is a `@MainActor` `ObservableObject` singleton holding `configuration`, `showsMenuBarExtra`, and `hapticsEnabled`. Every write is mirrored to `UserDefaults` and clamped to `GestureConfiguration.Limits` on both load and store, so a corrupt preference file can never make the surface unresponsive. It takes a `UserDefaults` in its initializer so `AppSettingsTests` runs against an isolated suite.

---

## Layer 4: UI composition

- **`App/MacRemoteApp.swift`** — `@main` SwiftUI `App` with three scenes: a titled `WindowGroup` (id `"main"`, resizable down to its content's minimum size); a `Settings` scene hosting `SettingsView`; and a `MenuBarExtra` whose insertion is bound to `AppSettings.showsMenuBarExtra`. A `Controls` `CommandMenu` mirrors every action with keyboard shortcuts (⌘↩ play/pause, ⌘←/⌘→ tracks, ⇧⌘←/⇧⌘→ rewind/fast-forward, ⌘↑/⌘↓ volume, ⇧⌘M mute, ⌥⌘↑/⌥⌘↓ brightness, ⌘L lock, Sleep).
- **`Views/ContentView.swift`** — root view; wraps `RemoteControlView` and sets a minimum/ideal size.
- **`Views/RemoteControlView.swift`** — the full remote: header, an **Accessibility banner** (shown while `AccessibilityPermission.isTrusted` is false, with "Open System Settings" and "Request Access" buttons), touch surface, `GroupBox` sections (Volume / Media / System), and a status line that shows `lastError` in red when present or `lastCommand` otherwise.
- **`Views/SettingsView.swift`** — a grouped `Form`: one labelled slider per threshold (bounded by `GestureConfiguration.Limits`), Reset to Defaults, and the menu bar / haptics toggles.
- **`Views/MenuBarView.swift`** — menu items for the most-used commands plus "Open Mac Remote" (via `openWindow`) and Quit.
- **`Services/AccessibilityPermission.swift`** — `@MainActor` singleton publishing `isTrusted`. macOS provides no notification for changes to the Accessibility list, so it polls `AXIsProcessTrusted()` every two seconds *only while untrusted* and stops once access is granted.
- **`Utilities/HapticEngine.swift`** — `@MainActor` singleton over `NSHapticFeedbackManager.defaultPerformer`; every pattern routes through one `perform` that honours `AppSettings.hapticsEnabled`.

### Interface conventions (macOS HIG)

- **Adaptive appearance** — semantic colors and materials (`.primary`/`.secondary`/`.tint`/`.quaternary`, `Color(nsColor:)`) instead of hardcoded RGB.
- **Standard controls & structure** — `GroupBox` sections, `.bordered`/`.borderedProminent` buttons, native `Slider`, `Toggle`, `Form`, `LabeledContent`, semantic typography.
- **Full keyboard access** — the `Controls` menu exposes every command with a shortcut; state-reflecting controls are two-way bound.
- **Accessibility** — interactive views carry `.help(_:)` tooltips and `.accessibilityLabel`/`.accessibilityHint`/`.accessibilityValue`. The drag surface is a single labelled element that points VoiceOver users at the equivalent buttons.

---

## Testing and CI

- **`MacRemoteTests`** (XCTest, app-hosted) covers the pure logic: gesture classification and mapping, settings persistence and clamping, and the command vocabulary. System-event synthesis is deliberately untested — it can only be verified on a real Mac with Accessibility granted.
- **`.github/workflows/ci.yml`** runs `xcodebuild build` and `xcodebuild test` for the shared `MacRemote` scheme on a macOS runner for every push and pull request, with code signing disabled. Logs are uploaded as artifacts.

---

## Platform, build, and permissions

- **Language / UI:** Swift 5.0, SwiftUI.
- **Deployment target:** macOS 13.0.
- **Bundle identifier:** `com.example.MacRemote` (tests: `com.example.MacRemoteTests`) — change before distributing.
- **Info.plist:** checked in (`GENERATE_INFOPLIST_FILE = NO`). Declares `NSAppleEventsUsageDescription` (required, or macOS refuses Apple events outright), display name, category, and disables automatic/sudden termination so listeners stay alive.
- **Frameworks:** AppKit, ApplicationServices, CoreAudio, Carbon, CoreGraphics, os — no third-party dependencies, no package manager.
- **Build:** shared scheme `MacRemote`; hardened runtime enabled on the app target for notarization.

### Runtime permissions

- **Accessibility** — required for every synthesized HID event. Detected and explained in-app.
- **Automation / Apple Events** — required only for `sleep`.

### Sandbox posture

`MacRemote.entitlements` keeps **App Sandbox** on and adds exactly what the app needs: `com.apple.security.automation.apple-events` (hardened-runtime permission to *ask* for Automation) and `com.apple.security.temporary-exception.apple-events` scoped to `com.apple.systemevents` (sandbox permission to actually deliver the event). The unused user-selected-file entitlement was removed. Synthesizing HID events from a sandboxed app works once Accessibility access is granted; distributing through the Mac App Store would still be at the reviewer's discretion because of that requirement.

---

## Known rough edges

- **Private media-key event synthesis is fragile.** The `NX_KEYTYPE_*` constants and the `NSEvent` subtype/modifier-mask packing are undocumented; behavior can change across macOS versions, so test on-device after edits.
- **`⌃⌘Q` lock assumes the default shortcut.** If a user has rebound or disabled the system lock shortcut, the lock command does nothing.
- **Scroll is delivered on release**, as one delta for the whole drag, rather than continuously while dragging.
- **macOS only.** This target is a Mac app controlling the Mac it runs on.

---

## Possible future direction

The original ambition — a *networked* universal remote that discovers and controls Apple TV (MediaRemote), HomeKit/Matter accessories, and Bluetooth LE devices over Wi-Fi — would reuse the one abstraction that already exists here: `UniversalCommand`. The natural extension is a **protocol-translator layer** behind the service, where each transport implements a translator from `UniversalCommand` to its wire format, and the current local-event path becomes just one translator among several. None of that is built today.
