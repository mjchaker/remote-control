//
//  TouchSurfaceView.swift
//  MacRemote
//
//  Gesture-based touch surface for controlling the Mac
//

import SwiftUI

/// Interactive touch surface that recognizes gestures.
///
/// The view only collects raw drag data into a `GestureState`; classification
/// is delegated to the pure `GestureRecognizer`, and thresholds come from the
/// user's persisted `AppSettings`.
struct TouchSurfaceView: View {
    @ObservedObject private var mediaService = MediaControlService.shared
    @ObservedObject private var settings = AppSettings.shared
    @State private var gestureState = GestureState()
    @State private var lastGesture: GestureType = .none
    @State private var isPressed = false

    var body: some View {
        ZStack {
            // Surface uses a system material and separator so it adapts to
            // Light/Dark appearance rather than hardcoded colors.
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.quaternary)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                )

            // Visual feedback
            VStack(spacing: 8) {
                if isPressed {
                    Circle()
                        .fill(.tint.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .scaleEffect(isPressed ? 1.0 : 0.5)
                        .animation(.spring(response: 0.3), value: isPressed)
                }

                Text(lastGesture.description)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .opacity(isPressed ? 1.0 : 0.6)

                if gestureState.isActive {
                    VStack(spacing: 4) {
                        Text("Δx: \(Int(gestureState.translation.width))")
                        Text("Δy: \(Int(gestureState.translation.height))")
                    }
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
                }
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    handleGestureChange(value)
                }
                .onEnded { value in
                    handleGestureEnd(value)
                }
        )
        // Drag gestures can't be operated by VoiceOver; describe the surface
        // and point users to the equivalent buttons below.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Trackpad")
        .accessibilityHint("Tap to play or pause, swipe up or down for volume, swipe left or right to change tracks, and drag to scroll. The buttons below perform the same actions.")
    }

    // MARK: - Gesture Handling

    private var config: GestureConfiguration { settings.configuration }

    private func handleGestureChange(_ value: DragGesture.Value) {
        if !gestureState.isActive {
            gestureState.startLocation = value.location
            gestureState.startTime = Date()
            gestureState.isActive = true
            isPressed = true
        }

        gestureState.currentLocation = value.location

        // Live label while dragging; the final classification happens on release.
        if gestureState.distance > config.tapMaxMovement {
            let dx = value.translation.width * config.scrollSensitivity
            let dy = value.translation.height * config.scrollSensitivity
            lastGesture = .scroll(dx: dx, dy: dy)
        }
    }

    private func handleGestureEnd(_ value: DragGesture.Value) {
        gestureState.currentLocation = value.location

        let translation = gestureState.translation
        let duration = gestureState.duration
        let recognizedGesture = GestureRecognizer.classify(
            translation: CGSize(
                width: translation.width * config.scrollSensitivity,
                height: translation.height * config.scrollSensitivity
            ),
            duration: duration,
            configuration: config
        )
        lastGesture = recognizedGesture

        // Execute the appropriate command
        if let command = GestureRecognizer.command(for: recognizedGesture) {
            Task { await mediaService.execute(command) }
        }

        // Reset state
        gestureState.reset()
        isPressed = false

        // Haptic feedback
        HapticEngine.shared.selection()
    }
}

// MARK: - Preview

#Preview {
    TouchSurfaceView()
        .frame(width: 400, height: 500)
        .padding()
}
