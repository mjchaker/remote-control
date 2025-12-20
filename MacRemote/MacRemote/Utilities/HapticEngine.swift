//
//  HapticEngine.swift
//  MacRemote
//
//  Haptic feedback engine for gesture acknowledgment
//

import Foundation
import AppKit

/// Manages haptic feedback for user interactions
class HapticEngine {
    static let shared = HapticEngine()

    private init() {}

    /// Trigger light haptic feedback
    func light() {
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment,
            performanceTime: .default
        )
    }

    /// Trigger medium haptic feedback
    func medium() {
        NSHapticFeedbackManager.defaultPerformer.perform(
            .levelChange,
            performanceTime: .default
        )
    }

    /// Trigger heavy haptic feedback
    func heavy() {
        NSHapticFeedbackManager.defaultPerformer.perform(
            .generic,
            performanceTime: .default
        )
    }

    /// Trigger selection haptic feedback
    func selection() {
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment,
            performanceTime: .default
        )
    }

    /// Trigger success haptic feedback
    func success() {
        NSHapticFeedbackManager.defaultPerformer.perform(
            .levelChange,
            performanceTime: .default
        )
    }

    /// Trigger error haptic feedback
    func error() {
        NSHapticFeedbackManager.defaultPerformer.perform(
            .generic,
            performanceTime: .default
        )
    }
}
