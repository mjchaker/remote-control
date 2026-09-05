//
//  MacRemoteApp.swift
//  MacRemote
//
//  Main app entry point
//

import SwiftUI

@main
struct MacRemoteApp: App {
    static let mainWindowID = "main"

    @ObservedObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup("Mac Remote", id: Self.mainWindowID) {
            ContentView()
        }
        // Allow the window to be resized down to its content's minimum size,
        // rather than locking it to a fixed size (HIG: prefer resizable windows).
        .windowResizability(.contentMinSize)
        .commands {
            // Expose every control in the menu bar so the app is fully
            // keyboard- and VoiceOver-navigable, per macOS HIG.
            CommandMenu("Controls") {
                Button("Play/Pause") { run(.media(.playPause)) }
                    .keyboardShortcut(.return, modifiers: .command)
                Button("Previous Track") { run(.media(.previous)) }
                    .keyboardShortcut(.leftArrow, modifiers: .command)
                Button("Next Track") { run(.media(.next)) }
                    .keyboardShortcut(.rightArrow, modifiers: .command)
                Button("Rewind") { run(.media(.rewind)) }
                    .keyboardShortcut(.leftArrow, modifiers: [.command, .shift])
                Button("Fast Forward") { run(.media(.fastForward)) }
                    .keyboardShortcut(.rightArrow, modifiers: [.command, .shift])

                Divider()

                Button("Volume Up") { run(.volume(.up)) }
                    .keyboardShortcut(.upArrow, modifiers: .command)
                Button("Volume Down") { run(.volume(.down)) }
                    .keyboardShortcut(.downArrow, modifiers: .command)
                Button("Mute") { run(.volume(.mute)) }
                    .keyboardShortcut("m", modifiers: [.command, .shift])

                Divider()

                Button("Brightness Up") { run(.system(.brightnessUp)) }
                    .keyboardShortcut(.upArrow, modifiers: [.command, .option])
                Button("Brightness Down") { run(.system(.brightnessDown)) }
                    .keyboardShortcut(.downArrow, modifiers: [.command, .option])

                Divider()

                Button("Lock Screen") { run(.system(.lock)) }
                    .keyboardShortcut("l", modifiers: .command)
                Button("Sleep") { run(.system(.sleep)) }
            }
        }

        Settings {
            SettingsView()
        }

        MenuBarExtra(
            "Mac Remote",
            systemImage: "playpause.circle",
            isInserted: $settings.showsMenuBarExtra
        ) {
            MenuBarView()
        }
        .menuBarExtraStyle(.menu)
    }

    /// Dispatch a command to the shared control service from a menu action.
    private func run(_ command: UniversalCommand) {
        Task {
            HapticEngine.shared.light()
            await MediaControlService.shared.execute(command)
        }
    }
}
