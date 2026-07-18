# remote-control

A native **macOS** app that turns your Mac into a gesture-driven media and system remote. A large touch surface and a set of buttons control playback, volume, brightness, navigation, and screen lock by synthesizing macOS system events — no extra hardware, no networking.

The working app lives in [`MacRemote/`](MacRemote/) and is a **proof of concept**: it controls the Mac it runs on (not a separate device over the network).

## Features

- **Gesture touch surface** — tap to play/pause, long-press for back, swipe up/down for volume, swipe left/right for previous/next track, drag to scroll.
- **Media controls** — play/pause, next/previous track, fast-forward/rewind (via system media keys).
- **Volume** — a slider that sets the system level directly, plus up/down and a mute toggle, through CoreAudio.
- **System** — brightness up/down, screen lock (and system sleep supported in the service layer).
- **Keyboard & menu** — every action is in the **Controls** menu with a keyboard shortcut for full keyboard access.
- **Native macOS UI** — standard controls and semantic colors that adapt to Light/Dark mode and your accent color.
- **Haptics** — trackpad feedback on gestures and button presses.

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later (Swift 5)

## Build & run

Open the project in Xcode and run (⌘R):

```bash
open MacRemote/MacRemote.xcodeproj
```

Or from the command line on a Mac with Xcode:

```bash
xcodebuild -project MacRemote/MacRemote.xcodeproj -scheme MacRemote build
```

On first launch macOS will prompt for **Accessibility** permission (required for synthesized key/scroll events) and **Automation** permission (required for screen lock, which uses AppleScript).

## Documentation

- [`MacRemote/README.md`](MacRemote/README.md) — usage, gesture reference, and troubleshooting.
- [`DESIGN.md`](DESIGN.md) — technical design of the implementation.
- [`CLAUDE.MD`](CLAUDE.MD) — orientation for AI assistants working in this repo.

> **Note:** an earlier vision for this project described a networked *universal* remote controlling Apple TV, HomeKit/Matter, and Bluetooth devices over Wi-Fi. That is **not implemented** — the current app is the local macOS proof of concept described above. See the "future direction" note in `DESIGN.md`.

## License

MIT — see [LICENSE](LICENSE).
