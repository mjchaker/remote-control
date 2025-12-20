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
        let flags = NSEvent.EventTypeMask.systemDefined.rawValue
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
        lastCommand = action.rawValue

        switch action {
        case .up:
            adjustVolume(by: 0.05)
        case .down:
            adjustVolume(by: -0.05)
        case .mute:
            toggleMute()
        case .setLevel:
            // This would be used with a slider
            break
        }

        updateVolumeState()
    }

    /// Adjust system volume
    private func adjustVolume(by delta: Float) {
        var outputVolume: Float32 = currentVolume
        var size = UInt32(MemoryLayout<Float32>.size)

        var defaultOutputDeviceID = AudioDeviceID(0)
        var deviceIDSize = UInt32(MemoryLayout.size(ofValue: defaultOutputDeviceID))

        var deviceIDAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &deviceIDAddress,
            0,
            nil,
            &deviceIDSize,
            &defaultOutputDeviceID
        )

        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectGetPropertyData(
            defaultOutputDeviceID,
            &volumeAddress,
            0,
            nil,
            &size,
            &outputVolume
        )

        outputVolume = min(max(outputVolume + delta, 0.0), 1.0)

        AudioObjectSetPropertyData(
            defaultOutputDeviceID,
            &volumeAddress,
            0,
            nil,
            size,
            &outputVolume
        )

        currentVolume = outputVolume
    }

    /// Toggle system mute
    private func toggleMute() {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var deviceIDSize = UInt32(MemoryLayout.size(ofValue: defaultOutputDeviceID))

        var deviceIDAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &deviceIDAddress,
            0,
            nil,
            &deviceIDSize,
            &defaultOutputDeviceID
        )

        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var mute: UInt32 = isMuted ? 0 : 1
        var size = UInt32(MemoryLayout<UInt32>.size)

        AudioObjectSetPropertyData(
            defaultOutputDeviceID,
            &muteAddress,
            0,
            nil,
            size,
            &mute
        )

        isMuted = !isMuted
    }

    /// Update current volume state from system
    private func updateVolumeState() {
        var outputVolume: Float32 = 0.5
        var size = UInt32(MemoryLayout<Float32>.size)

        var defaultOutputDeviceID = AudioDeviceID(0)
        var deviceIDSize = UInt32(MemoryLayout.size(ofValue: defaultOutputDeviceID))

        var deviceIDAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &deviceIDAddress,
            0,
            nil,
            &deviceIDSize,
            &defaultOutputDeviceID
        )

        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectGetPropertyData(
            defaultOutputDeviceID,
            &volumeAddress,
            0,
            nil,
            &size,
            &outputVolume
        )

        currentVolume = outputVolume
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
        let flags = NSEvent.EventTypeMask.systemDefined.rawValue
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
