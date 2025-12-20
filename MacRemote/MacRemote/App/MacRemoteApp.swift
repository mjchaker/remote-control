//
//  MacRemoteApp.swift
//  MacRemote
//
//  Main app entry point
//

import SwiftUI

@main
struct MacRemoteApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
