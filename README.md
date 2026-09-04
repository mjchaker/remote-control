# remote-control

A native **macOS** app that turns your Mac into a gesture-driven media and system remote. A large touch surface, a set of buttons, a menu bar extra, and a full set of keyboard shortcuts control playback, volume, brightness, navigation, sleep, and screen lock by synthesizing macOS system events — no extra hardware, no networking.

The app lives in [`MacRemote/`](MacRemote/). It controls the Mac it runs on, not a separate device over the network.

[![CI](https://github.com/mjchaker/remote-control/actions/workflows/ci.yml/badge.svg)](https://github.com/mjchaker/remote-control/actions/workflows/ci.yml)

## Features

- **Gesture touch surface** — tap to play/pause, long-press for back, swipe up/down for volume, swipe left/right for previous/next track, drag to scroll. Thresholds are tunable in Settings (⌘,).
- **Media controls** — play/pause, next/previous track, fast-forward/rewind via system media keys.
- **Volume** — a slider that sets the system level directly, up/down, and a mute toggle through CoreAudio. The slider **tracks changes made outside the app** (hardware keys, other apps, switching output devices).
- **System** — brightness up/down, screen lock, and sleep.
- **Menu bar remote** — an optional compact remote in the menu bar for quick access without the window.
- **Keyboard & menu** — every action is in the **Controls** menu with a keyboard shortcut for full keyboard access.
- **Permission guidance** — the app detects when Accessibility access is missing, explains why, and links straight to the right System Settings pane. Failures are reported in the status line instead of disappearing into the console.
- **Native macOS UI** — standard controls and semantic colors that adapt to Light/Dark mode and your accent color.
- **Haptics** — trackpad feedback on gestures and button presses (can be turned off in Settings).

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later (Swift 5)

## Build, run, test

Open the project in Xcode and run (⌘R):

```bash
open MacRemote/MacRemote.xcodeproj
```

Or from the command line on a Mac with Xcode:

```bash
xcodebuild -project MacRemote/MacRemote.xcodeproj -scheme MacRemote -destination 'platform=macOS' build
xcodebuild -project MacRemote/MacRemote.xcodeproj -scheme MacRemote -destination 'platform=macOS' test
```

The same two commands run on every push and pull request via GitHub Actions ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)).

On first launch macOS will prompt for **Accessibility** permission (required for synthesized key, media-key, and scroll events). The **Sleep** command additionally asks for **Automation** permission the first time you use it, because it drives System Events via AppleScript.

## Documentation

- [`MacRemote/README.md`](MacRemote/README.md) — usage, gesture reference, settings, and troubleshooting.
- [`DESIGN.md`](DESIGN.md) — technical design of the implementation.
- [`CLAUDE.MD`](CLAUDE.MD) — orientation for AI assistants working in this repo.

> **Note:** an earlier vision for this project described a networked *universal* remote controlling Apple TV, HomeKit/Matter, and Bluetooth devices over Wi-Fi. That is **not implemented** — this repository is the local macOS app described above. See the "future direction" note in `DESIGN.md`.

## License

MIT — see [LICENSE](LICENSE).
