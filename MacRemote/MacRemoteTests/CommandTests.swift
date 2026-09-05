//
//  CommandTests.swift
//  MacRemoteTests
//
//  Unit tests for the command vocabulary
//

import XCTest

final class CommandTests: XCTestCase {
    func testEveryMediaActionHasDisplayNameAndSymbol() {
        for action in MediaAction.allCases {
            XCTAssertFalse(action.rawValue.isEmpty, "\(action) has no display name")
            XCTAssertFalse(action.systemImageName.isEmpty, "\(action) has no symbol")
        }
    }

    func testEverySystemActionHasDisplayNameAndSymbol() {
        for action in SystemAction.allCases {
            XCTAssertFalse(action.rawValue.isEmpty, "\(action) has no display name")
            XCTAssertFalse(action.systemImageName.isEmpty, "\(action) has no symbol")
        }
    }

    func testVolumeActionsHaveDisplayNamesAndSymbols() {
        let actions: [VolumeAction] = [.up, .down, .mute, .setLevel(0.5)]
        for action in actions {
            XCTAssertFalse(action.displayName.isEmpty)
            XCTAssertFalse(action.systemImageName.isEmpty)
        }
    }

    func testNavigationActionsHaveDescriptions() {
        let actions: [NavigationAction] = [.up, .down, .left, .right, .select, .back, .scroll(dx: 1, dy: 1)]
        for action in actions {
            XCTAssertFalse(action.description.isEmpty)
        }
    }

    func testUniversalCommandEquality() {
        XCTAssertEqual(UniversalCommand.volume(.setLevel(0.25)), .volume(.setLevel(0.25)))
        XCTAssertNotEqual(UniversalCommand.volume(.setLevel(0.25)), .volume(.setLevel(0.5)))
        XCTAssertNotEqual(UniversalCommand.media(.next), .media(.previous))
    }
}
