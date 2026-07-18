//
//  RemoteControlView.swift
//  MacRemote
//
//  Main remote control interface with touch surface and buttons
//

import SwiftUI

/// Main remote control interface
struct RemoteControlView: View {
    @StateObject private var mediaService = MediaControlService.shared

    var body: some View {
        VStack(spacing: 16) {
            headerSection

            TouchSurfaceView()
                .frame(maxWidth: .infinity, minHeight: 220, maxHeight: .infinity)

            volumeSection
            mediaSection
            systemSection

            statusSection
        }
        .padding()
        // No custom background: use the standard window background so the app
        // adapts to Light/Dark appearance and accent color automatically.
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 2) {
            Text("Mac Remote")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Gesture control for your Mac")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Volume

    private var volumeSection: some View {
        GroupBox("Volume") {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "speaker.fill")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)

                    Slider(value: volumeBinding, in: 0...1)
                        .accessibilityLabel("Volume")

                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)

                    Text(volumePercentText)
                        .font(.body)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .trailing)
                        .accessibilityHidden(true)
                }

                Toggle(isOn: muteBinding) {
                    Label(
                        mediaService.isMuted ? "Muted" : "Mute",
                        systemImage: mediaService.isMuted ? "speaker.slash.fill" : "speaker.fill"
                    )
                }
                .toggleStyle(.button)
                .controlSize(.large)
                .help("Mute or unmute system audio (⇧⌘M)")
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Media

    private var mediaSection: some View {
        GroupBox("Media") {
            HStack(spacing: 12) {
                commandButton(
                    "Previous",
                    systemImage: "backward.fill",
                    help: "Previous track (⌘←)"
                ) {
                    await mediaService.execute(.media(.previous))
                }

                commandButton(
                    "Play/Pause",
                    systemImage: "playpause.fill",
                    prominent: true,
                    help: "Play or pause (⌘↩)"
                ) {
                    await mediaService.execute(.media(.playPause))
                }

                commandButton(
                    "Next",
                    systemImage: "forward.fill",
                    help: "Next track (⌘→)"
                ) {
                    await mediaService.execute(.media(.next))
                }
            }
        }
    }

    // MARK: - System

    private var systemSection: some View {
        GroupBox("System") {
            HStack(spacing: 12) {
                commandButton(
                    "Dim",
                    systemImage: "sun.min.fill",
                    help: "Decrease display brightness"
                ) {
                    await mediaService.execute(.system(.brightnessDown))
                }

                commandButton(
                    "Brighten",
                    systemImage: "sun.max.fill",
                    help: "Increase display brightness"
                ) {
                    await mediaService.execute(.system(.brightnessUp))
                }

                commandButton(
                    "Lock",
                    systemImage: "lock.fill",
                    help: "Lock the screen (⌘L)"
                ) {
                    await mediaService.execute(.system(.lock))
                }
            }
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            Text(mediaService.lastCommand)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Last command: \(mediaService.lastCommand)")
    }

    // MARK: - Bindings

    private var volumeBinding: Binding<Double> {
        Binding(
            get: { Double(mediaService.currentVolume) },
            set: { newValue in
                Task { await mediaService.execute(.volume(.setLevel(Float(newValue)))) }
            }
        )
    }

    private var muteBinding: Binding<Bool> {
        Binding(
            get: { mediaService.isMuted },
            set: { _ in
                Task {
                    HapticEngine.shared.light()
                    await mediaService.execute(.volume(.mute))
                }
            }
        )
    }

    private var volumePercentText: String {
        "\(Int((mediaService.currentVolume * 100).rounded()))%"
    }

    // MARK: - Reusable command button

    @ViewBuilder
    private func commandButton(
        _ title: String,
        systemImage: String,
        prominent: Bool = false,
        help: String,
        action: @escaping () async -> Void
    ) -> some View {
        let button = Button {
            Task {
                HapticEngine.shared.light()
                await action()
            }
        } label: {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .help(help)
        .accessibilityLabel(title)

        if prominent {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.bordered)
        }
    }
}

// MARK: - Preview

#Preview {
    RemoteControlView()
        .frame(width: 400, height: 680)
}
