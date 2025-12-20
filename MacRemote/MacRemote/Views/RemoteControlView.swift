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
        VStack(spacing: 20) {
            // Header
            headerSection

            // Touch Surface
            TouchSurfaceView()
                .frame(height: 400)

            // Volume Control
            volumeSection

            // Media Control Buttons
            mediaButtonsSection

            // System Control Buttons
            systemButtonsSection

            // Status
            statusSection
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.15),
                    Color(red: 0.15, green: 0.15, blue: 0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Mac Remote")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)

            Text("Gesture-based control for your Mac")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    // MARK: - Volume Section

    private var volumeSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "speaker.fill")
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 24)

                Slider(value: Binding(
                    get: { Double(mediaService.currentVolume) },
                    set: { _ in
                        Task {
                            // Note: Slider is for display only
                            // Use volume buttons for actual control
                        }
                    }
                ), in: 0...1)
                .tint(.blue)

                Image(systemName: "speaker.wave.3.fill")
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 24)
            }

            HStack(spacing: 12) {
                controlButton(
                    icon: "speaker.slash.fill",
                    title: "Mute"
                ) {
                    await mediaService.execute(.volume(.mute))
                }

                Spacer()

                Text("\(Int(mediaService.currentVolume * 100))%")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 60)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }

    // MARK: - Media Buttons

    private var mediaButtonsSection: some View {
        VStack(spacing: 12) {
            Text("Media Controls")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                controlButton(
                    icon: MediaAction.previous.systemImageName,
                    title: "Previous"
                ) {
                    await mediaService.execute(.media(.previous))
                }

                controlButton(
                    icon: MediaAction.playPause.systemImageName,
                    title: "Play/Pause",
                    primary: true
                ) {
                    await mediaService.execute(.media(.playPause))
                }

                controlButton(
                    icon: MediaAction.next.systemImageName,
                    title: "Next"
                ) {
                    await mediaService.execute(.media(.next))
                }
            }
        }
    }

    // MARK: - System Buttons

    private var systemButtonsSection: some View {
        VStack(spacing: 12) {
            Text("System Controls")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                controlButton(
                    icon: SystemAction.brightnessDown.systemImageName,
                    title: "Dim"
                ) {
                    await mediaService.execute(.system(.brightnessDown))
                }

                controlButton(
                    icon: SystemAction.brightnessUp.systemImageName,
                    title: "Bright"
                ) {
                    await mediaService.execute(.system(.brightnessUp))
                }

                controlButton(
                    icon: SystemAction.lock.systemImageName,
                    title: "Lock"
                ) {
                    await mediaService.execute(.system(.lock))
                }
            }
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        HStack {
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)

            Text(mediaService.lastCommand)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    // MARK: - Control Button

    @ViewBuilder
    private func controlButton(
        icon: String,
        title: String,
        primary: Bool = false,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            Task {
                HapticEngine.shared.light()
                await action()
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: primary ? 28 : 22))
                    .foregroundColor(.white)
                    .frame(height: 32)

                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        primary ?
                        Color.blue.opacity(0.3) :
                        Color.white.opacity(0.1)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        primary ?
                        Color.blue.opacity(0.5) :
                        Color.white.opacity(0.2),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    RemoteControlView()
        .frame(width: 400, height: 900)
}
