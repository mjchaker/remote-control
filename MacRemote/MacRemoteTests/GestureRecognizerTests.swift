//
//  GestureRecognizerTests.swift
//  MacRemoteTests
//
//  Unit tests for the pure gesture classifier
//

import XCTest
@testable import MacRemote

final class GestureRecognizerTests: XCTestCase {
    private let config = GestureConfiguration.default

    private func classify(_ dx: CGFloat, _ dy: CGFloat, duration: TimeInterval) -> GestureType {
        GestureRecognizer.classify(
            translation: CGSize(width: dx, height: dy),
            duration: duration,
            configuration: config
        )
    }

    // MARK: Taps and long presses

    func testShortPressWithNoMovementIsTap() {
        XCTAssertEqual(classify(0, 0, duration: 0.1), .tap)
    }

    func testSmallJitterStillCountsAsTap() {
        let jitter = config.tapMaxMovement - 1
        XCTAssertEqual(classify(jitter, 0, duration: 0.1), .tap)
    }

    func testHeldPressWithNoMovementIsLongPress() {
        XCTAssertEqual(classify(0, 0, duration: config.longPressDuration + 0.1), .longPress)
    }

    func testHeldPressAtExactThresholdIsStillTap() {
        XCTAssertEqual(classify(0, 0, duration: config.longPressDuration), .tap)
    }

    // MARK: Swipes

    func testFastHorizontalDragIsSwipeRight() {
        XCTAssertEqual(classify(120, 5, duration: 0.1), .swipeRight)
    }

    func testFastHorizontalDragIsSwipeLeft() {
        XCTAssertEqual(classify(-120, 5, duration: 0.1), .swipeLeft)
    }

    func testFastVerticalDragIsSwipeDown() {
        XCTAssertEqual(classify(5, 120, duration: 0.1), .swipeDown)
    }

    func testFastVerticalDragIsSwipeUp() {
        XCTAssertEqual(classify(5, -120, duration: 0.1), .swipeUp)
    }

    func testDominantAxisDecidesDiagonalSwipe() {
        XCTAssertEqual(classify(100, 80, duration: 0.1), .swipeRight)
        XCTAssertEqual(classify(80, -100, duration: 0.1), .swipeUp)
    }

    func testFastButShortDragIsNotASwipe() {
        // Faster than the velocity threshold but shorter than swipeThreshold.
        let distance = config.swipeThreshold - 5
        XCTAssertEqual(classify(distance, 0, duration: 0.05), .scroll(dx: distance, dy: 0))
    }

    // MARK: Scrolls

    func testSlowDragIsScrollCarryingTranslation() {
        XCTAssertEqual(classify(60, -30, duration: 2.0), .scroll(dx: 60, dy: -30))
    }

    func testZeroDurationDoesNotDivideByZero() {
        // A pathological zero-length gesture with movement must still classify.
        XCTAssertEqual(classify(120, 0, duration: 0), .swipeRight)
    }

    // MARK: Configuration is respected

    func testHigherVelocityThresholdTurnsSwipeIntoScroll() {
        var strict = config
        strict.swipeVelocityThreshold = 5_000
        let gesture = GestureRecognizer.classify(
            translation: CGSize(width: 120, height: 0),
            duration: 0.1,
            configuration: strict
        )
        XCTAssertEqual(gesture, .scroll(dx: 120, dy: 0))
    }

    // MARK: Gesture → command mapping

    func testGestureToCommandMapping() {
        XCTAssertEqual(GestureRecognizer.command(for: .tap), .media(.playPause))
        XCTAssertEqual(GestureRecognizer.command(for: .longPress), .navigation(.back))
        XCTAssertEqual(GestureRecognizer.command(for: .swipeUp), .volume(.up))
        XCTAssertEqual(GestureRecognizer.command(for: .swipeDown), .volume(.down))
        XCTAssertEqual(GestureRecognizer.command(for: .swipeLeft), .media(.previous))
        XCTAssertEqual(GestureRecognizer.command(for: .swipeRight), .media(.next))
        XCTAssertNil(GestureRecognizer.command(for: .none))
    }

    func testScrollDeltasAreHalved() {
        XCTAssertEqual(
            GestureRecognizer.command(for: .scroll(dx: 40, dy: -20)),
            .navigation(.scroll(dx: 20, dy: -10))
        )
    }
}
