//
//  GestureRecognizer.swift
//  MacRemote
//
//  Pure gesture classification, separated from view state so it can be unit tested
//

import Foundation

/// Classifies a completed drag into a `GestureType`.
///
/// `classify` is a pure function: given the same translation, duration, and
/// configuration it always returns the same gesture, and it touches no
/// external state. `TouchSurfaceView` supplies the arguments from its
/// `GestureState` at the moment the drag ends.
enum GestureRecognizer {
    /// Classify a finished gesture.
    ///
    /// Priority order:
    /// 1. **Long press** — little movement, held longer than `longPressDuration`
    /// 2. **Tap** — little movement, released quickly
    /// 3. **Swipe** — average velocity above `swipeVelocityThreshold` *and*
    ///    distance at least `swipeThreshold`; the dominant axis picks the direction
    /// 4. **Scroll** — everything else, carrying the raw translation as deltas
    static func classify(
        translation: CGSize,
        duration: TimeInterval,
        configuration config: GestureConfiguration
    ) -> GestureType {
        let dx = translation.width
        let dy = translation.height
        let distance = sqrt(dx * dx + dy * dy)

        if distance < config.tapMaxMovement {
            return duration > config.longPressDuration ? .longPress : .tap
        }

        let dt = max(duration, 0.001)
        let averageVelocity = distance / dt

        if averageVelocity > config.swipeVelocityThreshold && distance >= config.swipeThreshold {
            if abs(dx) > abs(dy) {
                return dx > 0 ? .swipeRight : .swipeLeft
            } else {
                return dy > 0 ? .swipeDown : .swipeUp
            }
        }

        return .scroll(dx: dx, dy: dy)
    }

    /// The command a recognized gesture maps to, or `nil` for `.none`.
    ///
    /// Scroll deltas are halved so a full drag across the surface scrolls a
    /// comfortable amount rather than a whole page.
    static func command(for gesture: GestureType) -> UniversalCommand? {
        switch gesture {
        case .tap:
            return .media(.playPause)
        case .longPress:
            return .navigation(.back)
        case .swipeUp:
            return .volume(.up)
        case .swipeDown:
            return .volume(.down)
        case .swipeLeft:
            return .media(.previous)
        case .swipeRight:
            return .media(.next)
        case .scroll(let dx, let dy):
            return .navigation(.scroll(dx: dx * 0.5, dy: dy * 0.5))
        case .none:
            return nil
        }
    }
}
