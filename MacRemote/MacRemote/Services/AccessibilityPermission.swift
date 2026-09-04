//
//  AccessibilityPermission.swift
//  MacRemote
//
//  Tracks whether macOS has granted this app Accessibility access
//

import Foundation
import AppKit
import ApplicationServices
import Combine

/// Observes the Accessibility (assistive access) permission.
///
/// Synthesized keyboard, media-key, and scroll events are silently dropped by
/// macOS unless the app is trusted under System Settings → Privacy & Security
/// → Accessibility. There is no notification for changes to that setting, so
/// while access is missing this object polls `AXIsProcessTrusted()` every
/// couple of seconds and stops polling once access is granted.
@MainActor
final class AccessibilityPermission: ObservableObject {
    static let shared = AccessibilityPermission()

    /// `true` when macOS will deliver the events this app synthesizes.
    @Published private(set) var isTrusted: Bool

    private var pollTimer: Timer?
    private let pollInterval: TimeInterval = 2.0

    private init() {
        isTrusted = AXIsProcessTrusted()
        if !isTrusted {
            startPolling()
        }
    }

    /// Re-read the permission state from the system.
    func refresh() {
        let trusted = AXIsProcessTrusted()
        if trusted != isTrusted {
            isTrusted = trusted
        }
        if trusted {
            stopPolling()
        } else {
            startPolling()
        }
    }

    /// Ask macOS to show its standard "would like to control this computer"
    /// prompt, which adds the app to the Accessibility list (unchecked).
    func requestAccess() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        isTrusted = AXIsProcessTrustedWithOptions(options)
        if !isTrusted {
            startPolling()
        }
    }

    /// Open the Accessibility pane of System Settings.
    func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Polling

    private func startPolling() {
        guard pollTimer == nil else { return }
        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}
