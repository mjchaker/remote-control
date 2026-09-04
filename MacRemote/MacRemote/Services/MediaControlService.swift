//
//  MediaControlService.swift
//  MacRemote
//
//  Service for controlling media playback, volume, and system functions on the local Mac
//

import Foundation
import AppKit
import ApplicationServices
import Carbon
import CoreAudio
import os

/// Service that executes control commands on the local Mac.
///
/// This is the only type that touches system APIs. Every command enters via
/// `execute(_:)`; each handler reports what it did through `lastCommand` and
/// any failure through `lastError`, so the UI never has to guess whether an
/// action reached the system.
@MainActor
final class MediaControlService: ObservableObject {
    /// Human-readable name of the most recent command.
    @Published var lastCommand: String = "Ready"
    /// Current system output volume, 0.0–1.0, kept live via CoreAudio listeners.
    @Published var currentVolume: Float = 0.5
    /// Whether the default output device is muted, kept live via CoreAudio listeners.
    @Published var isMuted: Bool = false
    /// Description of the most recent failure, or `nil` if the last command succeeded.
    @Published var lastError: String?

    static let shared = MediaControlService()

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MacRemote",
        category: "MediaControlService"
    )

    private init() {
        updateVolumeState()
        startObservingVolume()
    }

    /// Execute a universal command
    func execute(_ command: UniversalCommand) async {
        lastError = nil

        switch command {
        case .media(let action):
            executeMediaAction(action)
        case .volume(let action):
            executeVolumeAction(action)
        case .navigation(let action):
            executeNavigationAction(action)
        case .system(let action):
            executeSystemAction(action)
        }
    }

    // MARK: - Error reporting

    static let accessibilityRequiredMessage =
        "Accessibility access is required. Enable Mac Remote in System Settings → Privacy & Security → Accessibility."

    private func report(_ message: String) {
        Self.logger.error("\(message, privacy: .public)")
        lastError = message
    }

    /// Synthesized HID events are dropped unless the app is trusted for
    /// Accessibility. Surface that once per command instead of failing silently.
    @discardableResult
    private func requireAccessibility() -> Bool {
        if AXIsProcessTrusted() {
            return true
        }
        report(Self.accessibilityRequiredMessage)
        return false
    }

    // MARK: - Media Actions

    private func executeMediaAction(_ action: MediaAction) {
        lastCommand = action.rawValue

        let keyCode: Int32
        switch action {
        case .playPause:
            keyCode = NX_KEYTYPE_PLAY
        case .next:
            keyCode = NX_KEYTYPE_NEXT
        case .previous:
            keyCode = NX_KEYTYPE_PREVIOUS
        case .fastForward:
            keyCode = NX_KEYTYPE_FAST
        case .rewind:
            keyCode = NX_KEYTYPE_REWIND
        }

        sendSystemDefinedKey(keyCode)
    }

    /// Send a media/brightness key press (key down + key up) as a
    /// system-defined HID event, the same event the keyboard's media keys emit.
    private func sendSystemDefinedKey(_ keyCode: Int32) {
        guard requireAccessibility() else { return }

        let data1 = Int((keyCode << 16) | Int32((0xa << 8)))

        for (modifierFlags, isDown) in [(0xa00, true), (0xb00, false)] {
            let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: NSPoint.zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(modifierFlags)),
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            )

            guard let cgEvent = event?.cgEvent else {
                report("Could not create media key event (\(isDown ? "down" : "up")).")
                return
            }
            cgEvent.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Volume Actions

    private func executeVolumeAction(_ action: VolumeAction) {
        lastCommand = action.displayName

        switch action {
        case .up:
            adjustVolume(by: 0.05)
        case .down:
            adjustVolume(by: -0.05)
        case .mute:
            toggleMute()
        case .setLevel(let level):
            setVolume(to: level)
        }

        updateVolumeState()
    }

    // MARK: CoreAudio helpers

    private static let mainElement = AudioObjectPropertyElement(kAudioObjectPropertyElementMain)
    private static let stereoChannels: [AudioObjectPropertyElement] = [1, 2]

    /// Resolve the system's default audio output device, if any.
    private func defaultOutputDevice() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID
        )

        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }

    private func outputAddress(
        _ selector: AudioObjectPropertySelector,
        element: AudioObjectPropertyElement
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
    }

    /// Elements that expose `selector` on `device`: the main (master) element
    /// when the device has one, otherwise the individual stereo channels.
    /// Many USB and HDMI outputs only publish per-channel controls.
    private func controlElements(
        for selector: AudioObjectPropertySelector,
        on device: AudioDeviceID
    ) -> [AudioObjectPropertyElement] {
        var address = outputAddress(selector, element: Self.mainElement)
        if AudioObjectHasProperty(device, &address) {
            return [Self.mainElement]
        }
        return Self.stereoChannels.filter { channel in
            var channelAddress = outputAddress(selector, element: channel)
            return AudioObjectHasProperty(device, &channelAddress)
        }
    }

    /// Read the current output volume scalar (0.0–1.0), if available.
    private func readVolume() -> Float? {
        guard let device = defaultOutputDevice(),
              let element = controlElements(for: kAudioDevicePropertyVolumeScalar, on: device).first
        else { return nil }

        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = outputAddress(kAudioDevicePropertyVolumeScalar, element: element)

        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &volume)
        return status == noErr ? volume : nil
    }

    /// Read whether the output device is currently muted, if available.
    private func readMute() -> Bool? {
        guard let device = defaultOutputDevice(),
              let element = controlElements(for: kAudioDevicePropertyMute, on: device).first
        else { return nil }

        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = outputAddress(kAudioDevicePropertyMute, element: element)

        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value)
        return status == noErr ? (value != 0) : nil
    }

    // MARK: Volume mutation

    /// Set the output volume to an absolute level (clamped to 0.0–1.0).
    private func setVolume(to level: Float) {
        guard let device = defaultOutputDevice() else {
            report("No audio output device is available.")
            return
        }

        let elements = controlElements(for: kAudioDevicePropertyVolumeScalar, on: device)
        guard !elements.isEmpty else {
            report("The current output device does not allow volume control.")
            return
        }

        var value = min(max(level, 0.0), 1.0)
        let size = UInt32(MemoryLayout<Float32>.size)
        var failed = false

        for element in elements {
            var address = outputAddress(kAudioDevicePropertyVolumeScalar, element: element)
            let status = AudioObjectSetPropertyData(device, &address, 0, nil, size, &value)
            if status != noErr {
                failed = true
                Self.logger.error("Volume write failed on element \(element): \(status)")
            }
        }

        if failed {
            report("The system refused the volume change.")
            return
        }

        currentVolume = value
        // Raising volume from a muted state should unmute, matching hardware keys.
        if value > 0, isMuted {
            setMute(false)
        }
    }

    /// Adjust system volume by a relative delta.
    private func adjustVolume(by delta: Float) {
        let current = readVolume() ?? currentVolume
        setVolume(to: current + delta)
    }

    /// Set the output device mute state.
    private func setMute(_ muted: Bool) {
        guard let device = defaultOutputDevice() else {
            report("No audio output device is available.")
            return
        }

        let elements = controlElements(for: kAudioDevicePropertyMute, on: device)
        guard !elements.isEmpty else {
            report("The current output device does not support mute.")
            return
        }

        var value: UInt32 = muted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        var failed = false

        for element in elements {
            var address = outputAddress(kAudioDevicePropertyMute, element: element)
            let status = AudioObjectSetPropertyData(device, &address, 0, nil, size, &value)
            if status != noErr {
                failed = true
                Self.logger.error("Mute write failed on element \(element): \(status)")
            }
        }

        if failed {
            report("The system refused the mute change.")
            return
        }

        isMuted = muted
    }

    /// Toggle system mute.
    private func toggleMute() {
        setMute(!(readMute() ?? isMuted))
    }

    /// Refresh published volume/mute state from the system.
    private func updateVolumeState() {
        if let volume = readVolume(), volume != currentVolume {
            currentVolume = volume
        }
        if let muted = readMute(), muted != isMuted {
            isMuted = muted
        }
    }

    // MARK: Live volume observation

    private var deviceListenerBlock: AudioObjectPropertyListenerBlock?
    private var observedDevice: AudioDeviceID?
    private var observedAddresses: [AudioObjectPropertyAddress] = []
    private var defaultDeviceListenerBlock: AudioObjectPropertyListenerBlock?

    /// Subscribe to volume, mute, and default-device changes so the published
    /// state tracks changes made outside the app (hardware keys, other apps,
    /// plugging in headphones).
    private func startObservingVolume() {
        let defaultBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.observeCurrentDevice()
                self.updateVolumeState()
            }
        }
        var defaultAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &defaultAddress, DispatchQueue.main, defaultBlock
        )
        if status == noErr {
            defaultDeviceListenerBlock = defaultBlock
        } else {
            Self.logger.error("Could not observe default output device: \(status)")
        }

        observeCurrentDevice()
    }

    /// (Re)attach volume/mute listeners to whichever device is now the default.
    private func observeCurrentDevice() {
        removeDeviceListeners()

        guard let device = defaultOutputDevice() else { return }

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.updateVolumeState()
            }
        }

        var addresses: [AudioObjectPropertyAddress] = []
        for selector in [kAudioDevicePropertyVolumeScalar, kAudioDevicePropertyMute] {
            for element in controlElements(for: selector, on: device) {
                var address = outputAddress(selector, element: element)
                if AudioObjectAddPropertyListenerBlock(device, &address, DispatchQueue.main, block) == noErr {
                    addresses.append(address)
                }
            }
        }

        if !addresses.isEmpty {
            deviceListenerBlock = block
            observedDevice = device
            observedAddresses = addresses
        }
    }

    private func removeDeviceListeners() {
        guard let device = observedDevice, let block = deviceListenerBlock else { return }
        for var address in observedAddresses {
            AudioObjectRemovePropertyListenerBlock(device, &address, DispatchQueue.main, block)
        }
        observedDevice = nil
        observedAddresses = []
        deviceListenerBlock = nil
    }

    // MARK: - Navigation Actions

    private func executeNavigationAction(_ action: NavigationAction) {
        lastCommand = action.description

        let keyCode: CGKeyCode
        switch action {
        case .up:
            keyCode = CGKeyCode(kVK_UpArrow)
        case .down:
            keyCode = CGKeyCode(kVK_DownArrow)
        case .left:
            keyCode = CGKeyCode(kVK_LeftArrow)
        case .right:
            keyCode = CGKeyCode(kVK_RightArrow)
        case .select:
            keyCode = CGKeyCode(kVK_Return)
        case .back:
            keyCode = CGKeyCode(kVK_Delete)
        case .scroll(let dx, let dy):
            simulateScroll(dx: dx, dy: dy)
            return
        }

        simulateKeyPress(keyCode)
    }

    /// Simulate a key press (down + up), optionally with modifier flags.
    private func simulateKeyPress(_ keyCode: CGKeyCode, flags: CGEventFlags = []) {
        guard requireAccessibility() else { return }

        let source = CGEventSource(stateID: .hidSystemState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else {
            report("Could not create keyboard event.")
            return
        }

        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    /// Simulate scroll event
    private func simulateScroll(dx: CGFloat, dy: CGFloat) {
        guard requireAccessibility() else { return }

        let source = CGEventSource(stateID: .hidSystemState)
        guard let scrollEvent = CGEvent(
            scrollWheelEvent2Source: source,
            units: .pixel,
            wheelCount: 2,
            wheel1: Int32(dy),
            wheel2: Int32(dx),
            wheel3: 0
        ) else {
            report("Could not create scroll event.")
            return
        }
        scrollEvent.post(tap: .cghidEventTap)
    }

    // MARK: - System Actions

    private func executeSystemAction(_ action: SystemAction) {
        lastCommand = action.rawValue

        switch action {
        case .brightnessUp:
            sendSystemDefinedKey(NX_KEYTYPE_BRIGHTNESS_UP)
        case .brightnessDown:
            sendSystemDefinedKey(NX_KEYTYPE_BRIGHTNESS_DOWN)
        case .sleep:
            putSystemToSleep()
        case .lock:
            lockScreen()
        }
    }

    /// Put the system to sleep via System Events. This is the one action that
    /// still needs Apple Events (Automation permission); there is no public
    /// API for requesting sleep without elevated privileges.
    private func putSystemToSleep() {
        executeAppleScript("tell application \"System Events\" to sleep")
    }

    /// Lock the screen with the system-wide ⌃⌘Q shortcut, posted as a HID
    /// event so it needs only Accessibility access, not Automation.
    private func lockScreen() {
        simulateKeyPress(CGKeyCode(kVK_ANSI_Q), flags: [.maskCommand, .maskControl])
    }

    /// Execute AppleScript, surfacing any error to the UI.
    private func executeAppleScript(_ script: String) {
        guard let scriptObject = NSAppleScript(source: script) else {
            report("Could not compile AppleScript.")
            return
        }

        var error: NSDictionary?
        scriptObject.executeAndReturnError(&error)

        if let error {
            let code = error[NSAppleScript.errorNumber] as? Int ?? 0
            let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
            if code == -1743 {
                // errAEEventNotPermitted: the user declined Automation access.
                report("Automation access is required. Allow Mac Remote to control System Events in System Settings → Privacy & Security → Automation.")
            } else {
                report("AppleScript failed (\(code)): \(message)")
            }
        }
    }
}
