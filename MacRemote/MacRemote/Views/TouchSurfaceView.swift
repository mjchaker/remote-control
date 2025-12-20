//
//  TouchSurfaceView.swift
//  MacRemote
//
//  Gesture-based touch surface for controlling the Mac
//

import SwiftUI

/// Interactive touch surface that recognizes gestures
struct TouchSurfaceView: View {
    @StateObject private var mediaService = MediaControlService.shared
    @State private var gestureState = GestureState()
    @State private var config = GestureConfiguration()
    @State private var lastGesture: GestureType = .none
    @State private var isPressed = false

    var body: some View {
        ZStack {
            // Background with gradient
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.gray.opacity(0.2),
                            Color.gray.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                )

            // Visual feedback
            VStack(spacing: 8) {
                if isPressed {
                    Circle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .scaleEffect(isPressed ? 1.0 : 0.5)
                        .animation(.spring(response: 0.3), value: isPressed)
                }

                Text(lastGesture.description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .opacity(isPressed ? 1.0 : 0.5)

                if gestureState.isActive {
                    VStack(spacing: 4) {
                        Text("Δx: \(Int(gestureState.translation.width))")
                        Text("Δy: \(Int(gestureState.translation.height))")
                    }
                    .font(.system(size: 10, weight: .light, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    handleGestureChange(value)
                }
                .onEnded { value in
                    handleGestureEnd(value)
                }
        )
    }

    // MARK: - Gesture Handling

    private func handleGestureChange(_ value: DragGesture.Value) {
        if !gestureState.isActive {
            gestureState.startLocation = value.location
            gestureState.startTime = Date()
            gestureState.isActive = true
            isPressed = true
        }

        gestureState.currentLocation = value.location

        // Continuous scroll for small movements
        if gestureState.distance > config.tapMaxMovement {
            let dx = value.translation.width * config.scrollSensitivity
            let dy = value.translation.height * config.scrollSensitivity

            // Update visual feedback
            lastGesture = .scroll(dx: dx, dy: dy)
        }
    }

    private func handleGestureEnd(_ value: DragGesture.Value) {
        gestureState.currentLocation = value.location

        let recognizedGesture = recognizeGesture()
        lastGesture = recognizedGesture

        // Execute the appropriate command
        executeGesture(recognizedGesture)

        // Reset state
        gestureState.reset()
        isPressed = false

        // Haptic feedback
        HapticEngine.shared.selection()
    }

    /// Recognize what type of gesture was performed
    private func recognizeGesture() -> GestureType {
        let distance = gestureState.distance
        let duration = gestureState.duration
        let translation = gestureState.translation
        let velocity = gestureState.velocity
        let totalVelocity = sqrt(velocity.width * velocity.width + velocity.height * velocity.height)

        // Long press
        if distance < config.tapMaxMovement && duration > config.longPressDuration {
            return .longPress
        }

        // Tap
        if distance < config.tapMaxMovement {
            return .tap
        }

        // Swipe (high velocity movement)
        if totalVelocity > config.swipeVelocityThreshold {
            if abs(translation.width) > abs(translation.height) {
                return translation.width > 0 ? .swipeRight : .swipeLeft
            } else {
                return translation.height > 0 ? .swipeDown : .swipeUp
            }
        }

        // Scroll (low velocity movement)
        return .scroll(dx: translation.width, dy: translation.height)
    }

    /// Execute the command based on the gesture
    private func executeGesture(_ gesture: GestureType) {
        Task {
            switch gesture {
            case .tap:
                // Tap = Play/Pause
                await mediaService.execute(.media(.playPause))

            case .longPress:
                // Long press = Context menu / back
                await mediaService.execute(.navigation(.back))

            case .swipeUp:
                // Swipe up = Volume up
                await mediaService.execute(.volume(.up))

            case .swipeDown:
                // Swipe down = Volume down
                await mediaService.execute(.volume(.down))

            case .swipeLeft:
                // Swipe left = Previous track
                await mediaService.execute(.media(.previous))

            case .swipeRight:
                // Swipe right = Next track
                await mediaService.execute(.media(.next))

            case .scroll(let dx, let dy):
                // Scroll = Navigation
                await mediaService.execute(.navigation(.scroll(dx: dx * 0.5, dy: dy * 0.5)))

            case .none:
                break
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TouchSurfaceView()
        .frame(width: 400, height: 500)
        .padding()
        .background(Color.black)
}
