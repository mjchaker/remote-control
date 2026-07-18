//
//  MediaControlService.swift
//  MacRemote
//
//  Service for controlling media playback, volume, and system functions on the local Mac
//

import Foundation
import AppKit
import Carbon
import CoreAudio

/// Service that executes control commands on the local Mac
@MainActor
class MediaControlService: ObservableObject {
    @Published var lastCommand: String = "Ready"
    @Published var currentVolume: Float = 0.5
    @Published var isMuted: Bool = false

    static let shared = MediaControlService()

    private init() {
        updateVolumeState()
    }

    /// Execute a universal command
    func execute(_ command: UniversalCommand) async {
        switch command {
        case .media(let action):
            await executeMediaAction(action)
        case .volume(let action):
            await executeVolumeAction(action)
        case .navigation(let action):
            await executeNavigationAction(action)
        case .system(let action):
            await executeSystemAction(action)
        }
    }

    // MARK: - Media Actions

    private func executeMediaAction(_ action: MediaAction) async {
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

        sendMediaKey(keyCode)
    }

    /// Send a media key press event
    private func sendMediaKey(_ keyCode: Int32) {
        let data1 = Int((keyCode << 16) | Int32((0xa << 8)))

        // Key down
        let down = NSEvent.otherEvent(
            with: .systemDefined,
            location: NSPoint.zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: 0xa00),
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: data1,
            data2: -1
        )
        down?.cgEvent?.post(tap: .cghidEventTap)

        // Key up
        let up = NSEvent.otherEvent(
            with: .systemDefined,
            location: NSPoint.zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: 0xb00),
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: data1,
            data2: -1
        )
        up?.cgEvent?.post(tap: .cghidEventTap)
    }

    // MARK: - Volume Actions

    private func executeVolumeAction(_ action: VolumeAction) async {
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
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )

        return status == noErr ? deviceID : nil
    }

    /// Read the current output volume scalar (0.0–1.0), if available.
    private func readVolume() -> Float? {
        guard let device = defaultOutputDevice() else { return nil }

        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &volume)
        return status == noErr ? volume : nil
    }

    /// Read whether the output device is currently muted, if available.
    private func readMute() -> Bool? {
        guard let device = defaultOutputDevice() else { return nil }

        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value)
        return status == noErr ? (value != 0) : nil
    }

    // MARK: Volume mutation

    /// Set the output volume to an absolute level (clamped to 0.0–1.0).
    private func setVolume(to level: Float) {
        guard let device = defaultOutputDevice() else { return }

        var value = min(max(level, 0.0), 1.0)
        let size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectSetPropertyData(device, &address, 0, nil, size, &value)
        if status == noErr {
            currentVolume = value
            // Raising volume from a muted state should unmute, matching hardware keys.
            if value > 0, isMuted {
                setMute(false)
            }
        }
    }

    /// Adjust system volume by a relative delta.
    private func adjustVolume(by delta: Float) {
        let current = readVolume() ?? currentVolume
        setVolume(to: current + delta)
    }

    /// Set the output device mute state.
    private func setMute(_ muted: Bool) {
        guard let device = defaultOutputDevice() else { return }

        var value: UInt32 = muted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectSetPropertyData(device, &address, 0, nil, size, &value)
        if status == noErr {
            isMuted = muted
        }
    }

    /// Toggle system mute.
    private func toggleMute() {
        setMute(!isMuted)
    }

    /// Refresh published volume/mute state from the system.
    private func updateVolumeState() {
        if let volume = readVolume() {
            currentVolume = volume
        }
        if let muted = readMute() {
            isMuted = muted
        }
    }

    // MARK: - Navigation Actions

    private func executeNavigationAction(_ action: NavigationAction) async {
        lastCommand = action.description

        // Navigation actions could simulate arrow key presses
        let keyCode: CGKeyCode
        switch action {
        case .up:
            keyCode = 126 // Up arrow
        case .down:
            keyCode = 125 // Down arrow
        case .left:
            keyCode = 123 // Left arrow
        case .right:
            keyCode = 124 // Right arrow
        case .select:
            keyCode = 36  // Return
        case .back:
            keyCode = 51  // Delete
        case .scroll(let dx, let dy):
            simulateScroll(dx: dx, dy: dy)
            return
        }

        simulateKeyPress(keyCode)
    }

    /// Simulate a key press
    private func simulateKeyPress(_ keyCode: CGKeyCode) {
        let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)

        keyDownEvent?.post(tap: .cghidEventTap)
        keyUpEvent?.post(tap: .cghidEventTap)
    }

    /// Simulate scroll event
    private func simulateScroll(dx: CGFloat, dy: CGFloat) {
        let scrollEvent = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: Int32(dy),
            wheel2: Int32(dx),
            wheel3: 0
        )
        scrollEvent?.post(tap: .cghidEventTap)
    }

    // MARK: - System Actions

    private func executeSystemAction(_ action: SystemAction) async {
        lastCommand = action.rawValue

        switch action {
        case .brightnessUp:
            adjustBrightness(up: true)
        case .brightnessDown:
            adjustBrightness(up: false)
        case .sleep:
            putSystemToSleep()
        case .lock:
            lockScreen()
        }
    }

    /// Adjust screen brightness
    private func adjustBrightness(up: Bool) {
        let keyCode: Int32 = up ? NX_KEYTYPE_BRIGHTNESS_UP : NX_KEYTYPE_BRIGHTNESS_DOWN
        let data1 = Int((keyCode << 16) | Int32((0xa << 8)))

        let down = NSEvent.otherEvent(
            with: .systemDefined,
            location: NSPoint.zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: 0xa00),
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: data1,
            data2: -1
        )
        down?.cgEvent?.post(tap: .cghidEventTap)

        let upEvent = NSEvent.otherEvent(
            with: .systemDefined,
            location: NSPoint.zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: 0xb00),
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: data1,
            data2: -1
        )
        upEvent?.cgEvent?.post(tap: .cghidEventTap)
    }

    /// Put system to sleep
    private func putSystemToSleep() {
        let script = "tell application \"System Events\" to sleep"
        executeAppleScript(script)
    }

    /// Lock the screen
    private func lockScreen() {
        let script = "tell application \"System Events\" to keystroke \"q\" using {command down, control down}"
        executeAppleScript(script)
    }

    /// Execute AppleScript
    private func executeAppleScript(_ script: String) {
        if let scriptObject = NSAppleScript(source: script) {
            var error: NSDictionary?
            scriptObject.executeAndReturnError(&error)
            if let error = error {
                print("AppleScript error: \(error)")
            }
        }
    }
}
