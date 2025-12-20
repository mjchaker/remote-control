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

/// Configuration for gesture recognition thresholds
struct GestureConfiguration {
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
