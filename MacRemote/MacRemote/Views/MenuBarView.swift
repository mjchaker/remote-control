//
//  MenuBarView.swift
//  MacRemote
//
//  Compact remote shown from the menu bar
//

import SwiftUI

/// Contents of the `MenuBarExtra`: the most-used commands as menu items.
struct MenuBarView: View {
    @ObservedObject private var mediaService = MediaControlService.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Play/Pause") { run(.media(.playPause)) }
        Button("Previous Track") { run(.media(.previous)) }
        Button("Next Track") { run(.media(.next)) }

        Divider()

        Button("Volume Up") { run(.volume(.up)) }
        Button("Volume Down") { run(.volume(.down)) }
        Button(mediaService.isMuted ? "Unmute" : "Mute") { run(.volume(.mute)) }

        Divider()

        Button("Lock Screen") { run(.system(.lock)) }

        Divider()

        Button("Open Mac Remote") {
            openWindow(id: MacRemoteApp.mainWindowID)
            NSApp.activate(ignoringOtherApps: true)
        }
        Button("Quit Mac Remote") {
            NSApp.terminate(nil)
        }
    }

    private func run(_ command: UniversalCommand) {
        Task { await mediaService.execute(command) }
    }
}
