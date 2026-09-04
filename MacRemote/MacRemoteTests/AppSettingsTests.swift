//
//  AppSettingsTests.swift
//  MacRemoteTests
//
//  Unit tests for preference persistence and clamping
//

import XCTest
@testable import MacRemote

final class AppSettingsTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "MacRemoteTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    @MainActor
    func testFreshStoreYieldsFactoryDefaults() {
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.configuration, .default)
        XCTAssertTrue(settings.showsMenuBarExtra)
        XCTAssertTrue(settings.hapticsEnabled)
    }

    @MainActor
    func testConfigurationRoundTripsThroughDefaults() {
        var custom = GestureConfiguration.default
        custom.swipeThreshold = 75
        custom.longPressDuration = 0.8
        custom.tapMaxMovement = 12
        custom.scrollSensitivity = 2.0
        custom.swipeVelocityThreshold = 450

        AppSettings(defaults: defaults).configuration = custom

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.configuration, custom)
    }

    @MainActor
    func testOutOfRangeValuesAreClampedOnWrite() {
        let settings = AppSettings(defaults: defaults)
        var bad = GestureConfiguration.default
        bad.tapMaxMovement = 10_000
        bad.longPressDuration = -5

        settings.configuration = bad

        XCTAssertEqual(
            settings.configuration.tapMaxMovement,
            CGFloat(GestureConfiguration.Limits.tapMaxMovement.upperBound)
        )
        XCTAssertEqual(
            settings.configuration.longPressDuration,
            GestureConfiguration.Limits.longPressDuration.lowerBound
        )
    }

    @MainActor
    func testCorruptStoredValuesAreClampedOnLoad() {
        defaults.set(-100.0, forKey: AppSettings.Key.swipeVelocityThreshold)

        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(
            settings.configuration.swipeVelocityThreshold,
            CGFloat(GestureConfiguration.Limits.swipeVelocityThreshold.lowerBound)
        )
    }

    @MainActor
    func testResetRestoresDefaults() {
        let settings = AppSettings(defaults: defaults)
        settings.configuration.swipeThreshold = 150
        settings.resetGestureConfiguration()
        XCTAssertEqual(settings.configuration, .default)
    }

    @MainActor
    func testTogglesPersist() {
        let settings = AppSettings(defaults: defaults)
        settings.showsMenuBarExtra = false
        settings.hapticsEnabled = false

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertFalse(reloaded.showsMenuBarExtra)
        XCTAssertFalse(reloaded.hapticsEnabled)
    }
}
