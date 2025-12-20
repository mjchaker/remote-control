# MacRemote - Proof of Concept

A gesture-based remote control app for macOS that lets you control your Mac using touch gestures and buttons.

## Features

### Gesture-Based Touch Surface
- **Tap**: Play/Pause media
- **Long Press**: Back/Context menu
- **Swipe Up**: Volume up
- **Swipe Down**: Volume down
- **Swipe Left**: Previous track
- **Swipe Right**: Next track
- **Scroll**: Navigate/scroll (continuous small movements)

### Media Controls
- Play/Pause
- Next/Previous track
- Fast forward/Rewind
- Volume control with slider
- Mute/Unmute

### System Controls
- Brightness up/down
- Lock screen
- System sleep (coming soon)

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later

## Building the Project

1. Open `MacRemote.xcodeproj` in Xcode
2. Select your target device (Mac)
3. Build and run (⌘R)

## First Run Setup

On first launch, macOS will ask for permissions:

1. **Accessibility Access**: Required for controlling media playback and system functions
   - Go to System Settings > Privacy & Security > Accessibility
   - Add and enable MacRemote

2. **AppleScript Automation**: Required for system control features
   - Allow when prompted

## Usage

### Touch Surface
The large gray area is an interactive touch surface that recognizes different gestures:

- Perform gestures by clicking and dragging on the touch surface
- Visual feedback shows the current gesture and translation values
- Haptic feedback confirms gesture recognition (on supported trackpads)

### Control Buttons
- Use the media control buttons for quick access to common functions
- Volume slider for precise volume adjustment
- System controls for brightness and screen lock

### Status Display
The bottom status bar shows the last executed command.

## Architecture

### Project Structure
```
MacRemote/
├── App/
│   └── MacRemoteApp.swift          # Main app entry point
├── Models/
│   ├── Command.swift               # Command data models
│   └── GestureType.swift           # Gesture recognition types
├── Services/
│   └── MediaControlService.swift   # Media/system control service
├── Views/
│   ├── ContentView.swift           # Main content view
│   ├── TouchSurfaceView.swift      # Gesture-based touch surface
│   └── RemoteControlView.swift     # Remote control UI
└── Utilities/
    └── HapticEngine.swift          # Haptic feedback
```

### Key Technologies

- **SwiftUI**: Modern declarative UI framework
- **CoreAudio**: System volume control
- **Carbon**: Media key event generation
- **AppKit**: System integration and haptic feedback
- **CGEvent**: Keyboard and scroll simulation

## Gesture Recognition

The touch surface uses a sophisticated gesture recognition system:

### Thresholds (customizable in `GestureConfiguration`)
- **Swipe Threshold**: 50 points minimum distance
- **Long Press Duration**: 0.5 seconds
- **Tap Max Movement**: 10 points
- **Swipe Velocity Threshold**: 300 points/second
- **Scroll Sensitivity**: 1.0x (adjustable)

### Recognition Logic
1. **Tap**: Short press with minimal movement
2. **Long Press**: Extended press with minimal movement
3. **Swipe**: High velocity movement in one direction
4. **Scroll**: Low velocity continuous movement

## Customization

### Gesture Sensitivity
Edit `GestureConfiguration` in `GestureType.swift`:

```swift
var config = GestureConfiguration()
config.swipeThreshold = 75.0        // Require longer swipes
config.scrollSensitivity = 2.0      // Make scrolling more sensitive
config.longPressDuration = 0.7      // Require longer press
```

### Gesture Mappings
Modify gesture-to-command mappings in `TouchSurfaceView.swift` -> `executeGesture()`:

```swift
case .tap:
    // Change from play/pause to something else
    await mediaService.execute(.media(.next))
```

## Known Limitations

1. **Accessibility Required**: App needs accessibility permissions to control system functions
2. **Media App Support**: Media controls work best with Apple Music, Spotify, and other media apps that support system media keys
3. **Volume Control**: Uses system-wide volume (not app-specific)
4. **Brightness Control**: May not work on external displays

## Troubleshooting

### Media controls not working
- Ensure accessibility permissions are granted
- Check that a media app (Music, Spotify, etc.) is running
- Try playing media first, then use controls

### Volume slider not updating
- The slider shows the last set value, not real-time system volume
- Use the volume up/down buttons for reliable feedback

### Gestures not recognized
- Try adjusting gesture thresholds in `GestureConfiguration`
- Make sure gestures are deliberate (not too slow, not too fast)
- Check the visual feedback on the touch surface

## Next Steps

This is a proof of concept. Future enhancements could include:

- [ ] Real-time volume level monitoring
- [ ] Customizable gesture mappings UI
- [ ] Multi-device support (control other Macs on network)
- [ ] Gesture recording and playback
- [ ] Menu bar mode with minimal UI
- [ ] Keyboard shortcuts
- [ ] Touch Bar support

## License

This is a proof of concept project. See parent repository for license information.
