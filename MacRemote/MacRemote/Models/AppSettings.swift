//
//  AppSettings.swift
//  MacRemote
//
//  User preferences persisted in UserDefaults
//

import Foundation
import Combine

/// Observable, persisted user preferences.
///
/// `configuration` is the single source of truth for gesture thresholds:
/// `TouchSurfaceView` reads it, `SettingsView` edits it, and every write is
/// mirrored to `UserDefaults` so it survives relaunch. Values are clamped on
/// both load and store so a bad preference file can never make the surface
/// unresponsive.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    /// Keys under which each preference is stored.
    enum Key {
        static let swipeThreshold = "gesture.swipeThreshold"
        static let longPressDuration = "gesture.longPressDuration"
        static let tapMaxMovement = "gesture.tapMaxMovement"
        static let scrollSensitivity = "gesture.scrollSensitivity"
        static let swipeVelocityThreshold = "gesture.swipeVelocityThreshold"
        static let showsMenuBarExtra = "ui.showsMenuBarExtra"
        static let hapticsEnabled = "ui.hapticsEnabled"
    }

    /// Gesture thresholds used by the touch surface.
    @Published var configuration: GestureConfiguration {
        didSet {
            // Assigning inside didSet does not re-trigger the observer, so
            // clamp here and persist the clamped value directly.
            let clamped = configuration.clamped()
            if clamped != configuration {
                configuration = clamped
            }
            store(clamped)
        }
    }

    /// Whether the compact menu bar remote is shown.
    @Published var showsMenuBarExtra: Bool {
        didSet { defaults.set(showsMenuBarExtra, forKey: Key.showsMenuBarExtra) }
    }

    /// Whether trackpad haptic feedback is played.
    @Published var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Key.hapticsEnabled) }
    }

    private let defaults: UserDefaults

    /// - Parameter defaults: the store to read from and write to. Tests pass
    ///   an isolated suite so they never touch the user's real preferences.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.configuration = AppSettings.load(from: defaults)
        self.showsMenuBarExtra = defaults.object(forKey: Key.showsMenuBarExtra) as? Bool ?? true
        self.hapticsEnabled = defaults.object(forKey: Key.hapticsEnabled) as? Bool ?? true
    }

    /// Restore the factory gesture thresholds.
    func resetGestureConfiguration() {
        configuration = .default
    }

    // MARK: - Persistence

    private static func load(from defaults: UserDefaults) -> GestureConfiguration {
        var config = GestureConfiguration.default

        func value(_ key: String) -> Double? {
            defaults.object(forKey: key) as? Double
        }

        if let v = value(Key.swipeThreshold) { config.swipeThreshold = CGFloat(v) }
        if let v = value(Key.longPressDuration) { config.longPressDuration = v }
        if let v = value(Key.tapMaxMovement) { config.tapMaxMovement = CGFloat(v) }
        if let v = value(Key.scrollSensitivity) { config.scrollSensitivity = CGFloat(v) }
        if let v = value(Key.swipeVelocityThreshold) { config.swipeVelocityThreshold = CGFloat(v) }

        return config.clamped()
    }

    private func store(_ config: GestureConfiguration) {
        defaults.set(Double(config.swipeThreshold), forKey: Key.swipeThreshold)
        defaults.set(config.longPressDuration, forKey: Key.longPressDuration)
        defaults.set(Double(config.tapMaxMovement), forKey: Key.tapMaxMovement)
        defaults.set(Double(config.scrollSensitivity), forKey: Key.scrollSensitivity)
        defaults.set(Double(config.swipeVelocityThreshold), forKey: Key.swipeVelocityThreshold)
    }
}
