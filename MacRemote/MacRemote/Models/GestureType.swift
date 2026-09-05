//
//  GestureType.swift
//  MacRemote
//
//  Gesture recognition types for the touch surface
//

import Foundation
import SwiftUI

/// Types of gestures recognized by the touch surface
enum GestureType: Equatable {
    case tap
    case longPress
    case swipeUp
    case swipeDown
    case swipeLeft
    case swipeRight
    case scroll(dx: CGFloat, dy: CGFloat)
    case none

    var description: String {
        switch self {
        case .tap: return "Tap"
        case .longPress: return "Long Press"
        case .swipeUp: return "Swipe Up"
        case .swipeDown: return "Swipe Down"
        case .swipeLeft: return "Swipe Left"
        case .swipeRight: return "Swipe Right"
        case .scroll: return "Scroll"
        case .none: return "None"
        }
    }
}

/// Configuration for gesture recognition thresholds.
///
/// This is a plain value type: `GestureRecognizer.classify` is a pure function
/// of a gesture's translation, its duration, and one of these configurations.
/// Persisted, user-editable values live in `AppSettings`.
struct GestureConfiguration: Equatable {
    /// Minimum distance (in points) to recognize a swipe
    var swipeThreshold: CGFloat = 50.0

    /// Minimum duration (in seconds) for long press
    var longPressDuration: TimeInterval = 0.5

    /// Maximum movement (in points) allowed for a tap
    var tapMaxMovement: CGFloat = 10.0

    /// Sensitivity multiplier for scroll gestures (higher = more sensitive)
    var scrollSensitivity: CGFloat = 1.0

    /// Velocity threshold to distinguish swipe from scroll
    var swipeVelocityThreshold: CGFloat = 300.0

    /// The factory defaults.
    static let `default` = GestureConfiguration()

    /// Allowed ranges for each tunable, used by the Settings UI and by
    /// `clamped()` so a corrupt or hand-edited preference can't disable input.
    enum Limits {
        static let swipeThreshold: ClosedRange<Double> = 10...200
        static let longPressDuration: ClosedRange<Double> = 0.2...2.0
        static let tapMaxMovement: ClosedRange<Double> = 2...40
        static let scrollSensitivity: ClosedRange<Double> = 0.1...5.0
        static let swipeVelocityThreshold: ClosedRange<Double> = 50...2000
    }

    /// Returns a copy with every field forced into its allowed range.
    func clamped() -> GestureConfiguration {
        var copy = self
        copy.swipeThreshold = CGFloat(Double(swipeThreshold).clamped(to: Limits.swipeThreshold))
        copy.longPressDuration = longPressDuration.clamped(to: Limits.longPressDuration)
        copy.tapMaxMovement = CGFloat(Double(tapMaxMovement).clamped(to: Limits.tapMaxMovement))
        copy.scrollSensitivity = CGFloat(Double(scrollSensitivity).clamped(to: Limits.scrollSensitivity))
        copy.swipeVelocityThreshold = CGFloat(Double(swipeVelocityThreshold).clamped(to: Limits.swipeVelocityThreshold))
        return copy
    }
}

extension Double {
    /// Clamp a value into a closed range.
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

/// Gesture state tracking
struct GestureState {
    var startLocation: CGPoint = .zero
    var currentLocation: CGPoint = .zero
    var startTime: Date = Date()
    var isActive: Bool = false

    var translation: CGSize {
        CGSize(
            width: currentLocation.x - startLocation.x,
            height: currentLocation.y - startLocation.y
        )
    }

    var distance: CGFloat {
        let dx = translation.width
        let dy = translation.height
        return sqrt(dx * dx + dy * dy)
    }

    var duration: TimeInterval {
        Date().timeIntervalSince(startTime)
    }

    var velocity: CGSize {
        let dt = max(duration, 0.001)
        return CGSize(
            width: translation.width / dt,
            height: translation.height / dt
        )
    }

    mutating func reset() {
        startLocation = .zero
        currentLocation = .zero
        startTime = Date()
        isActive = false
    }
}
