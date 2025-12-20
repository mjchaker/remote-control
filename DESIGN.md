# Universal Remote Control App - Technical Design Draft

## Executive Summary

You're essentially building a **software-defined remote control** that leverages Apple's built-in frameworks to communicate with smart home devices, media players, and displays—without any custom hardware. Think of it like the Control Center remote, but extensible and with deeper device integration.

Let me walk you through how this works conceptually, then dive into the architecture.

---

## How It All Works (The Mental Model)

### The Communication Stack

Imagine your iPhone as a **universal translator** sitting in your living room. It speaks several "languages":

```
┌─────────────────────────────────────────────────────────┐
│                    Your App                              │
├─────────────────────────────────────────────────────────┤
│  HomeKit / Matter  │  MediaRemote  │  Bluetooth LE      │
│  (Smart Home)      │  (Apple TV)   │  (Direct Control)  │
├─────────────────────────────────────────────────────────┤
│           Wi-Fi (IP Network)    │    Bluetooth Radio    │
├─────────────────────────────────────────────────────────┤
│                Physical Layer (Radio Waves)              │
│           2.4 GHz / 5 GHz       │      2.4 GHz          │
└─────────────────────────────────────────────────────────┘
```

**Key insight**: Wi-Fi and Bluetooth both operate in the 2.4 GHz radio spectrum—the same frequencies your microwave uses, but at vastly lower power levels (milliwatts vs. hundreds of watts). This is non-ionizing radiation, completely safe for humans.

### Why Matter Matters

Matter is like **Esperanto for smart home devices**. Before Matter, you had:
- HomeKit devices (Apple only)
- Zigbee devices (need a hub)
- Z-Wave devices (different hub)
- Proprietary Wi-Fi devices (each with their own app)

Matter creates a common language. Your app speaks Matter through HomeKit, and any Matter-certified device understands it—regardless of manufacturer.

```
Your App → HomeKit Framework → Matter Protocol → Any Matter Device
                                    ↓
                        (Thread, Wi-Fi, or Ethernet)
```

---

## Architecture Overview

### Layer 1: Device Discovery & Capability Negotiation

When your app launches, it needs to answer: "What can I control, and how?"

```swift
// Conceptual flow - not production code
protocol DiscoverableDevice {
    var id: UUID { get }
    var name: String { get }
    var capabilities: Set<DeviceCapability> { get }
    var connectionType: ConnectionType { get }
    
    func connect() async throws
    func disconnect()
}

enum DeviceCapability {
    case powerControl          // Can turn on/off
    case mediaPlayback         // Play/pause/skip
    case volumeControl         // Volume up/down/mute
    case textInput             // Can receive text
    case cursorNavigation      // D-pad style navigation
    case displayControl        // Brightness, sleep, etc.
}

enum ConnectionType {
    case homeKit               // Via Home.framework
    case mediaRemote           // Via MediaRemote.framework (Apple TV)
    case bluetoothLE           // Direct BLE connection
    case airPlay               // Screen mirroring targets
}
```

**Analogy**: Think of this like a diplomatic reception. When your app "meets" a device, they exchange credentials and figure out what topics they can discuss. A smart TV might say "I can do power, volume, and media" while a simple smart plug only offers "I can do power."

### Layer 2: The Control Surface

This is where the magic of "more than just tapping buttons" happens. The Control Center remote uses **gesture recognition** on a virtual trackpad:

```swift
// The touch surface interprets gestures contextually
struct TouchSurface: View {
    @State private var gestureState: GestureState = .idle
    
    var body: some View {
        Rectangle()
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // Small movements = cursor navigation
                        // Velocity-based = scroll/swipe
                        interpretGesture(value)
                    }
                    .onEnded { value in
                        // Quick tap vs. long press vs. swipe
                        finalizeGesture(value)
                    }
            )
    }
    
    private func interpretGesture(_ value: DragGesture.Value) {
        // This is where you can customize behavior:
        // - Sensitivity curves
        // - Gesture recognition thresholds  
        // - Haptic feedback triggers
    }
}
```

**The key insight**: The difference between a "tap" and a "swipe" is just math on touch coordinates over time. You have full control over these thresholds.

### Layer 3: Text Input Detection

Here's where it gets interesting. The Control Center remote knows when to show the keyboard because Apple TV **broadcasts** that a text field is focused. Your app listens for this:

```swift
// Simplified conceptual model
class TextInputObserver: ObservableObject {
    @Published var isTextInputActive: Bool = false
    @Published var currentTextFieldContent: String = ""
    
    // The MediaRemote framework provides notifications
    // when the paired device's keyboard state changes
    func startObserving(device: MediaRemoteDevice) {
        device.textInputStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.isTextInputActive = state.isActive
                if state.isActive {
                    // Trigger keyboard presentation
                    self?.presentKeyboard()
                }
            }
            .store(in: &cancellables)
    }
}
```

**Why this works**: Apple TV (and other AirPlay 2 receivers) implement a protocol where they announce UI state changes. It's like the TV saying "Hey, I'm showing a search box now—anyone want to type for me?"

### Layer 4: Power Control for Displays

This is where HomeKit/Matter shines. Modern smart TVs expose power state as a **characteristic**:

```swift
// HomeKit model for a television
class TelevisionAccessory {
    // These are standard HomeKit characteristics
    var powerState: HMCharacteristic       // On/Off
    var activeIdentifier: HMCharacteristic // Which input
    var sleepDiscoveryMode: HMCharacteristic
    
    func powerOff() async throws {
        try await powerState.writeValue(false)
    }
    
    func sleep() async throws {
        // Some displays support sleep vs. full power off
        try await sleepDiscoveryMode.writeValue(
            HMCharacteristicValueSleepDiscoveryMode.notDiscoverable
        )
    }
}
```

**Important distinction**: "Power off" vs. "Sleep" vs. "Screen off" are different things:
- **Power off**: Device fully shuts down (slow to wake)
- **Sleep**: Low-power state, quick wake (like closing a laptop)
- **Screen off**: Display dark but device fully running

Your app should expose all three where supported.

---

## Data Model

```swift
// Your app's core data types

struct ControlledDevice: Identifiable, Codable {
    let id: UUID
    var name: String
    var room: String?
    var deviceType: DeviceType
    var connectionInfo: ConnectionInfo
    var capabilities: Set<DeviceCapability>
    var lastSeen: Date
    var customizations: DeviceCustomizations
}

struct DeviceCustomizations: Codable {
    var gestureSensitivity: Double = 1.0      // 0.5 = less sensitive, 2.0 = more
    var hapticFeedbackEnabled: Bool = true
    var favoriteActions: [QuickAction] = []
    var buttonMapping: [PhysicalButton: Action]? // For BLE remotes
}

enum DeviceType: String, Codable {
    case television
    case speaker
    case streamingBox       // Apple TV, Roku, etc.
    case computer           // Mac
    case smartDisplay       // HomePod with screen, etc.
    case generic
}

struct ConnectionInfo: Codable {
    var homeKitAccessoryID: UUID?
    var blePeripheralID: UUID?
    var airPlayDeviceID: String?
    var ipAddress: String?
    var lastSuccessfulProtocol: ConnectionType?
}
```

---

## The Protocol Bridge Pattern

Since you're dealing with multiple connection types, I recommend a **bridge pattern** that normalizes commands:

```swift
// Abstract command that works across all protocols
enum UniversalCommand {
    case power(PowerAction)
    case navigation(NavigationAction)
    case media(MediaAction)
    case text(TextAction)
    case volume(VolumeAction)
}

enum PowerAction {
    case on, off, toggle, sleep, wake
}

enum NavigationAction {
    case up, down, left, right
    case select, back, home, menu
    case scroll(dx: CGFloat, dy: CGFloat)
}

// Each protocol implements its own translator
protocol CommandTranslator {
    func translate(_ command: UniversalCommand) -> ProtocolSpecificCommand
    func send(_ command: ProtocolSpecificCommand) async throws
}

class HomeKitTranslator: CommandTranslator {
    func translate(_ command: UniversalCommand) -> ProtocolSpecificCommand {
        switch command {
        case .power(.off):
            return .homeKit(.writeCharacteristic(powerState, value: false))
        // ... etc
        }
    }
}

class MediaRemoteTranslator: CommandTranslator {
    // Translates to MediaRemote.framework calls
}
```

**Why this matters for you**: When you want to add a new device type or protocol, you only need to write a new translator. The rest of your app stays unchanged.

---

## Radio Safety (Addressing Your Concern)

You mentioned wanting signals in the radio wave spectrum to avoid harm. Good news: **this is already guaranteed by the physics of Wi-Fi and Bluetooth**.

| Radiation Type | Frequency | Effect on Humans |
|---------------|-----------|------------------|
| Ionizing (X-rays, gamma) | > 10^15 Hz | Damages DNA ⚠️ |
| UV light | ~10^15 Hz | Skin damage at high exposure |
| Visible light | ~10^14 Hz | Safe |
| Infrared (old remotes) | ~10^13 Hz | Safe (heat at high power) |
| **Wi-Fi/Bluetooth** | **2.4 × 10^9 Hz** | **Completely safe** ✓ |
| FM Radio | ~10^8 Hz | Safe |

Your iPhone's transmit power is about **1-100 milliwatts**. For comparison, holding your phone to your ear during a call exposes you to more RF energy than any smart home control ever would.

**No additional safety measures needed**—Apple's hardware is already FCC certified for safe operation.

---

## Project Structure

```
UniversalRemote/
├── App/
│   ├── UniversalRemoteApp.swift
│   └── AppDelegate.swift           // For background modes
│
├── Core/
│   ├── Models/
│   │   ├── Device.swift
│   │   ├── Command.swift
│   │   └── Capability.swift
│   │
│   ├── Services/
│   │   ├── DeviceDiscoveryService.swift
│   │   ├── ConnectionManager.swift
│   │   └── CommandDispatcher.swift
│   │
│   └── Protocols/
│       ├── HomeKitBridge.swift
│       ├── MediaRemoteBridge.swift
│       └── BluetoothLEBridge.swift
│
├── Features/
│   ├── DeviceList/
│   │   ├── DeviceListView.swift
│   │   └── DeviceListViewModel.swift
│   │
│   ├── RemoteControl/
│   │   ├── RemoteControlView.swift
│   │   ├── TouchSurfaceView.swift
│   │   ├── GestureInterpreter.swift
│   │   └── RemoteControlViewModel.swift
│   │
│   └── TextInput/
│       ├── RemoteKeyboardView.swift
│       └── TextInputObserver.swift
│
├── Utilities/
│   ├── HapticEngine.swift
│   └── Logger.swift
│
└── Resources/
    ├── Info.plist                  // Privacy descriptions, background modes
    └── Entitlements.plist          // HomeKit, Bluetooth, etc.
```

---

## Required Entitlements & Permissions

```xml
<!-- Info.plist additions -->
<key>NSHomeKitUsageDescription</key>
<string>Control your smart home devices</string>

<key>NSBluetoothAlwaysUsageDescription</key>
<string>Connect to Bluetooth devices</string>

<key>NSLocalNetworkUsageDescription</key>
<string>Discover and control devices on your network</string>

<key>NSBonjourServices</key>
<array>
    <string>_hap._tcp</string>           <!-- HomeKit -->
    <string>_airplay._tcp</string>       <!-- AirPlay -->
    <string>_raop._tcp</string>          <!-- Remote Audio -->
    <string>_matter._tcp</string>        <!-- Matter -->
</array>

<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
    <string>external-accessory</string>
</array>
```

---

## Where You Can Customize & Extend

1. **Gesture Recognition** (`GestureInterpreter.swift`): Tune sensitivity curves, add custom gestures, change swipe thresholds

2. **Command Mapping**: The `UniversalCommand` → protocol translation is where you define what each action *means* for each device type

3. **Device Profiles**: Create preset configurations for common devices (Samsung TV, LG TV, Sonos, etc.) with optimized settings

4. **Automation Hooks**: Add shortcuts integration so users can trigger multi-device scenes ("Movie mode" = dim lights + TV on + soundbar to surround)

5. **Alternative Protocols**: The bridge pattern makes it straightforward to add MQTT, HTTP APIs, or other protocols for non-Apple devices

---

## Next Steps

1. **Prototype the touch surface first**—this is the core UX differentiator
2. **Start with Apple TV integration** (MediaRemote framework) since it's the most feature-complete
3. **Add HomeKit discovery** for power control of Matter/HomeKit devices
4. **Layer in the keyboard detection** once basic navigation works

Would you like me to elaborate on any of these layers, or shall we start drafting actual implementation code for a specific component?