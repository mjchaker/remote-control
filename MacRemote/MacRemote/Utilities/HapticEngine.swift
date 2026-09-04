//
//  HapticEngine.swift
//  MacRemote
//
//  Haptic feedback engine for gesture acknowledgment
//

import Foundation
import AppKit

/// Manages haptic feedback for user interactions.
///
/// All feedback is routed through `perform(_:)`, which honours the user's
/// "Haptic feedback" preference so a single switch silences every call site.
@MainActor
final class HapticEngine {
    static let shared = HapticEngine()

    private init() {}

    /// Trigger light haptic feedback
    func light() {
        perform(.alignment)
    }

    /// Trigger medium haptic feedback
    func medium() {
        perform(.levelChange)
    }

    /// Trigger heavy haptic feedback
    func heavy() {
        perform(.generic)
    }

    /// Trigger selection haptic feedback
    func selection() {
        perform(.alignment)
    }

    /// Trigger success haptic feedback
    func success() {
        perform(.levelChange)
    }

    /// Trigger error haptic feedback
    func error() {
        perform(.generic)
    }

    private func perform(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        guard AppSettings.shared.hapticsEnabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .default)
    }
}
