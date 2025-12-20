# CLAUDE.MD - Universal Remote Control App

## Project Overview

This is a **native Swift application** that transforms Apple devices (iPhone, iPad, Mac) into a sophisticated universal remote control for smart home devices, Apple TV, and HomeKit/Matter accessories. The app provides gesture-based navigation, automatic keyboard detection, and power management—all over Wi-Fi and Bluetooth with no additional hardware required.

**Think of it as**: A software-defined remote control that leverages Apple's built-in frameworks to communicate with smart devices without custom hardware—like an enhanced version of Control Center's remote with extensibility and deeper device integration.

## Tech Stack

- **Language**: Swift (native iOS/iPadOS/macOS)
- **UI Framework**: SwiftUI
- **Key Apple Frameworks**:
  - `HomeKit.framework` - Smart home device control (HomeKit/Matter)
  - `MediaRemote.framework` - Apple TV control and media playback
  - `CoreBluetooth` - Direct Bluetooth LE connections
  - `AirPlay` - Screen mirroring and media streaming targets
  - `Combine` - Reactive programming for state management

## Architecture Pattern

The app uses a **Protocol Bridge Pattern** to normalize commands across different connection types:

```
User Gesture → UniversalCommand → Protocol Translator → Device-Specific Command
```

### Core Layers

1. **Device Discovery & Capability Negotiation**: Discovers devices and their capabilities
2. **Control Surface**: Gesture recognition on virtual trackpad
3. **Text Input Detection**: Auto-shows keyboard when text fields are focused on target devices
4. **Power Control**: Manages power states (on/off/sleep) for displays

## Communication Protocols

- **HomeKit/Matter**: Smart home devices via Wi-Fi/Thread
- **MediaRemote**: Apple TV and AirPlay 2 receivers
- **Bluetooth LE**: Direct device control
- **Wi-Fi (IP Network)**: General network communication

**Safety Note**: All communications use non-ionizing radiation (2.4 GHz / 5 GHz) at milliwatt power levels—completely safe and FCC certified.

## Project Structure

```
UniversalRemote/
├── App/                        # App entry point and lifecycle
├── Core/
│   ├── Models/                 # Data models (Device, Command, Capability)
│   ├── Services/               # Business logic (Discovery, Connection, Dispatcher)
│   └── Protocols/              # Protocol bridges (HomeKit, MediaRemote, BLE)
├── Features/
│   ├── DeviceList/             # Device discovery and selection
│   ├── RemoteControl/          # Main remote UI with touch surface
│   └── TextInput/              # Keyboard input handling
├── Utilities/                  # Helpers (Haptics, Logging)
└── Resources/                  # Info.plist, Entitlements
```

## Key Concepts for Development

### 1. Device Capabilities

Not all devices support all features. The app discovers and respects device capabilities:

- `powerControl` - Can turn on/off
- `mediaPlayback` - Play/pause/skip
- `volumeControl` - Volume adjustment
- `textInput` - Can receive text
- `cursorNavigation` - D-pad style navigation
- `displayControl` - Brightness, sleep modes

### 2. Gesture Interpretation

The touch surface distinguishes between:
- **Tap**: Quick press and release
- **Long press**: Extended press for context menus
- **Swipe**: Velocity-based navigation
- **Scroll**: Continuous small movements

Sensitivity is customizable per device.

### 3. Power States

Three distinct states supported:
- **Power Off**: Full shutdown (slow wake)
- **Sleep**: Low-power state (quick wake)
- **Screen Off**: Display dark, device running

### 4. Connection Types

- **HomeKit**: Via `Home.framework` for certified accessories
- **MediaRemote**: For Apple TV and AirPlay 2 devices
- **Bluetooth LE**: Direct connections to BLE peripherals
- **AirPlay**: Screen mirroring targets

## Required Entitlements

The app requires these privacy permissions:
- `NSHomeKitUsageDescription` - Smart home control
- `NSBluetoothAlwaysUsageDescription` - Bluetooth connections
- `NSLocalNetworkUsageDescription` - Network device discovery
- `NSBonjourServices` - Service discovery (_hap._tcp, _airplay._tcp, _matter._tcp)
- `UIBackgroundModes` - Bluetooth and accessory background modes

## Development Guidelines

### When Adding New Features

1. **Start with the model**: Define the `UniversalCommand` first
2. **Implement protocol translators**: Add device-specific translation
3. **Update capabilities**: Ensure devices advertise new capabilities
4. **Test across protocols**: Verify with HomeKit, MediaRemote, and BLE

### When Adding New Device Types

1. Create a new `DeviceType` enum case
2. Implement a `CommandTranslator` for the protocol
3. Add capability discovery logic
4. Define default customizations for the device type

### Best Practices

- **Normalize everything**: Use `UniversalCommand` to keep UI protocol-agnostic
- **Respect capabilities**: Don't show controls for unsupported features
- **Fail gracefully**: Handle connection losses, timeout errors
- **Provide feedback**: Use haptics for gesture acknowledgment
- **Consider latency**: Some protocols (BLE) have higher latency than others

## Key Files to Understand

1. **DESIGN.md** - Comprehensive technical design with detailed explanations
2. **Device.swift** (future) - Core device model and capabilities
3. **CommandTranslator** (future) - Protocol bridge implementations
4. **GestureInterpreter** (future) - Touch gesture recognition logic

## Current Status

**Repository Status**: Initial setup phase
- Basic documentation in place (README, DESIGN, LICENSE)
- No implementation files yet
- Ready for prototype development

**Recommended Next Steps**:
1. Prototype the touch surface (core UX differentiator)
2. Implement Apple TV integration (MediaRemote framework)
3. Add HomeKit discovery for power control
4. Layer in keyboard detection

## Important Notes for AI Assistants

### Project Philosophy
- **No custom hardware required**: Leverage existing Apple frameworks
- **Universal compatibility**: Support multiple protocols via bridge pattern
- **User customization**: Allow per-device gesture sensitivity and button mapping
- **Safety-first**: All RF communications are inherently safe (non-ionizing, low power)

### Code Style Preferences
- Use SwiftUI for all UI components
- Prefer `async/await` over completion handlers
- Use Combine for reactive state management
- Follow Apple's Human Interface Guidelines
- Write protocol-oriented code for extensibility

### Testing Considerations
- Test with real devices (Apple TV, HomeKit accessories)
- Validate gesture recognition thresholds on different screen sizes
- Ensure smooth performance on older devices (iPhone X era)
- Test background mode behavior for connection persistence

### Constraints
- iOS 16+ target (for latest HomeKit/Matter features)
- Requires local network access (same Wi-Fi network)
- Some features need physical Apple TV or HomeKit devices for testing
- MediaRemote framework has limited documentation (reverse engineering needed)

## Questions to Ask

When implementing features, consider:
- Does this work across all connection types?
- Is the capability properly advertised?
- What happens if the device disconnects mid-operation?
- How does this feel on iPad vs iPhone vs Mac?
- Is the gesture threshold appropriate for this screen size?

## Resources

- [HomeKit Documentation](https://developer.apple.com/documentation/homekit)
- [Matter Specification](https://csa-iot.org/all-solutions/matter/)
- [CoreBluetooth Framework](https://developer.apple.com/documentation/corebluetooth)
- MediaRemote Framework - No official docs (private API, use with caution)

---

**Last Updated**: 2025-12-20
**Project Phase**: Planning & Documentation
**Target Platforms**: iOS 16+, iPadOS 16+, macOS 13+
