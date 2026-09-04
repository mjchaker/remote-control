# MacRemote

A gesture-based remote control app for macOS that lets you control your Mac using touch gestures, buttons, the menu bar, and keyboard shortcuts.

## Features

### Gesture-Based Touch Surface
- **Tap**: Play/Pause media
- **Long Press**: Back (Delete key)
- **Swipe Up**: Volume up
- **Swipe Down**: Volume down
- **Swipe Left**: Previous track
- **Swipe Right**: Next track
- **Drag**: Scroll (slow, continuous movement)

### Media Controls
- Play/Pause
- Next/Previous track
- Fast forward/Rewind (Controls menu)
- Volume slider that follows the real system volume
- Mute/Unmute

### System Controls
- Brightness up/down
- Lock screen
- Sleep (Controls menu)

### Menu Bar Remote
An optional compact remote in the menu bar (play/pause, tracks, volume, mute, lock) so the window doesn't have to be open. Toggle it in **Settings → General**.

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later

## Building and testing

1. Open `MacRemote.xcodeproj` in Xcode
2. Build and run (⌘R), or run the unit tests (⌘U)

From the command line:

```bash
xcodebuild -project MacRemote.xcodeproj -scheme MacRemote -destination 'platform=macOS' build
xcodebuild -project MacRemote.xcodeproj -scheme MacRemote -destination 'platform=macOS' test
```

The `MacRemote` scheme is shared and includes the `MacRemoteTests` unit-test target.

## First Run Setup

Mac Remote works by synthesizing the same events a keyboard or trackpad would send, which macOS only delivers from apps it trusts.

1. **Accessibility access** — required for every media, navigation, brightness, scroll, and lock command.
   - The app shows a banner with an **Open System Settings** button until access is granted.
   - Go to System Settings → Privacy & Security → Accessibility and enable **MacRemote**.
   - The banner disappears automatically once access is granted; no relaunch needed.

2. **Automation access** — required only for **Sleep**, which asks System Events to sleep the Mac.
   - macOS prompts the first time you use Sleep. Allow it, or manage it under Privacy & Security → Automation.

If a command can't be delivered, the status line at the bottom turns red and explains why.

## Usage

### Touch Surface
- Perform gestures by clicking and dragging on the touch surface
- Visual feedback shows the current gesture and translation values
- Haptic feedback confirms gesture recognition (on supported trackpads)

### Control Buttons
- Media buttons for previous / play-pause / next
- Volume slider sets the system volume directly; the mute toggle reflects the current state
- System buttons for brightness and screen lock

### Keyboard Shortcuts
Every action is available from the **Controls** menu in the menu bar:

| Shortcut | Action |
|----------|--------|
| ⌘↩ | Play/Pause |
| ⌘← / ⌘→ | Previous / Next track |
| ⇧⌘← / ⇧⌘→ | Rewind / Fast forward |
| ⌘↑ / ⌘↓ | Volume up / down |
| ⇧⌘M | Mute |
| ⌥⌘↑ / ⌥⌘↓ | Brightness up / down |
| ⌘L | Lock screen |
| — | Sleep |
| ⌘, | Settings |

### Status Display
The bottom status line shows the last executed command. If a command fails (for example because Accessibility access is missing), the dot turns red and the line shows the reason.

### Settings (⌘,)

**Gestures** — sliders for every recognition threshold, with a **Reset to Defaults** button:

| Setting | Default | Meaning |
|---------|---------|---------|
| Tap tolerance | 10 pt | Max pointer movement that still counts as a tap or long press |
| Long press duration | 0.5 s | Hold time before a press becomes a long press |
| Swipe distance | 50 pt | Minimum distance a fast drag must cover to be a swipe |
| Swipe speed | 300 pt/s | Drags faster than this are swipes; slower drags scroll |
| Scroll sensitivity | 1.0× | Multiplier applied to drag distance |

**General** — show/hide the menu bar remote; enable/disable haptic feedback.

Preferences are stored in `UserDefaults` and survive relaunch; out-of-range values are clamped so a bad preference can never make the surface unresponsive.

### Appearance
The interface uses standard macOS controls and semantic colors, so it adapts automatically to Light/Dark mode and your accent color.

## Architecture

### Project Structure
```
MacRemote/
├── App/
│   └── MacRemoteApp.swift            # @main: window, Controls menu, Settings, MenuBarExtra
├── Models/
│   ├── Command.swift                 # UniversalCommand + action enums
│   ├── GestureType.swift             # GestureType, GestureConfiguration, GestureState
│   ├── GestureRecognizer.swift       # Pure classifier + gesture→command mapping
│   └── AppSettings.swift             # Persisted preferences (thresholds, toggles)
├── Services/
│   ├── MediaControlService.swift     # Executes commands on the local Mac
│   └── AccessibilityPermission.swift # Tracks Accessibility trust, polls until granted
├── Views/
│   ├── ContentView.swift             # Root view, window sizing
│   ├── RemoteControlView.swift       # Main UI: banner, surface, controls, status
│   ├── TouchSurfaceView.swift        # Gesture surface (collects drag, delegates to recognizer)
│   ├── SettingsView.swift            # Settings window
│   └── MenuBarView.swift             # Menu bar extra contents
└── Utilities/
    └── HapticEngine.swift            # Haptic feedback (honours the Settings toggle)

MacRemoteTests/
├── GestureRecognizerTests.swift      # Classifier and mapping
├── AppSettingsTests.swift            # Persistence and clamping
└── CommandTests.swift                # Command vocabulary
```

### Key Technologies

- **SwiftUI**: Declarative UI, Settings scene, MenuBarExtra
- **CoreAudio**: System volume control and live volume/mute observation
- **Carbon**: Media key event generation and virtual key codes
- **AppKit / ApplicationServices**: Accessibility trust checks, haptics, AppleScript
- **CGEvent**: Keyboard, modifier, and scroll simulation
- **XCTest**: Unit tests for the pure logic

## Gesture Recognition

Classification is a pure function, `GestureRecognizer.classify(translation:duration:configuration:)`, evaluated when the drag ends:

1. **Long press**: movement under *Tap tolerance* and duration over *Long press duration*
2. **Tap**: movement under *Tap tolerance*, released sooner
3. **Swipe**: average speed over *Swipe speed* **and** distance at least *Swipe distance*; the dominant axis and its sign pick the direction
4. **Scroll**: anything else, carrying the drag's translation as scroll deltas

Because it depends only on its arguments, it is covered by unit tests and its thresholds can be edited live in Settings.

## Customization

Change thresholds in **Settings → Gestures**. To change what a gesture *does*, edit `GestureRecognizer.command(for:)`:

```swift
case .tap:
    return .media(.next)   // was .media(.playPause)
```

## Known Limitations

1. **Accessibility required**: without it, macOS drops every synthesized event. The app tells you when this is the case.
2. **Media app support**: media keys work with apps that honour system media keys (Music, Spotify, browsers, …).
3. **Volume control**: system-wide output volume, not per-app. Some devices expose neither a master nor per-channel volume control; the app reports this rather than pretending.
4. **Brightness**: may not affect external displays.
5. **Sleep needs Automation access**: it is the one command that goes through AppleScript.
6. **Sandboxed**: the app runs in the App Sandbox with an Apple-events exception for System Events. If you distribute outside the Mac App Store you will also need to sign and notarize it; the hardened runtime is already enabled.

## Troubleshooting

### Nothing happens when I press a button
- Look at the status line: a red dot means the command failed and the text says why.
- Most often Accessibility access is missing — use the banner's **Open System Settings** button.

### Media controls not working
- Check that a media app is running and has played something at least once.

### Volume slider doesn't move when I use the keyboard keys
- The slider listens for CoreAudio changes; if it stays still, the output device may not publish volume properties (some HDMI/USB devices). Try switching output devices.

### Gestures not recognized
- Open Settings (⌘,) and loosen the thresholds, or **Reset to Defaults**.
- Watch the label on the surface: it shows what was recognized.

### Sleep does nothing
- Allow the Automation prompt, or enable Mac Remote → System Events under Privacy & Security → Automation.

## Roadmap

- [x] Real-time volume level monitoring
- [x] Customizable gesture thresholds UI
- [x] Menu bar mode
- [x] Keyboard shortcuts
- [x] Unit tests and CI
- [ ] Customizable gesture → command mappings UI
- [ ] Launch at login
- [ ] Multi-device support (control other Macs on the network)

## License

MIT — see the parent repository's LICENSE.
