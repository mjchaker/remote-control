//
//  SettingsView.swift
//  MacRemote
//
//  Preferences window: gesture thresholds and app behaviour
//

import SwiftUI

/// The app's Settings window (⌘,).
struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("Gestures") {
                thresholdSlider(
                    "Tap tolerance",
                    value: cgFloatBinding(\.tapMaxMovement),
                    range: GestureConfiguration.Limits.tapMaxMovement,
                    format: "%.0f pt",
                    help: "How far the pointer may move and still count as a tap or long press."
                )
                thresholdSlider(
                    "Long press duration",
                    value: doubleBinding(\.longPressDuration),
                    range: GestureConfiguration.Limits.longPressDuration,
                    format: "%.1f s",
                    help: "How long to hold before a press becomes a long press (Back)."
                )
                thresholdSlider(
                    "Swipe distance",
                    value: cgFloatBinding(\.swipeThreshold),
                    range: GestureConfiguration.Limits.swipeThreshold,
                    format: "%.0f pt",
                    help: "Minimum distance a fast drag must cover to count as a swipe."
                )
                thresholdSlider(
                    "Swipe speed",
                    value: cgFloatBinding(\.swipeVelocityThreshold),
                    range: GestureConfiguration.Limits.swipeVelocityThreshold,
                    format: "%.0f pt/s",
                    help: "Drags faster than this are swipes; slower drags scroll."
                )
                thresholdSlider(
                    "Scroll sensitivity",
                    value: cgFloatBinding(\.scrollSensitivity),
                    range: GestureConfiguration.Limits.scrollSensitivity,
                    format: "%.1f×",
                    help: "Multiplier applied to drag distance before it becomes a scroll."
                )

                HStack {
                    Spacer()
                    Button("Reset to Defaults") {
                        settings.resetGestureConfiguration()
                    }
                    .disabled(settings.configuration == .default)
                }
            }

            Section("General") {
                Toggle("Show remote in the menu bar", isOn: $settings.showsMenuBarExtra)
                    .help("Adds a compact remote to the menu bar for quick access.")
                Toggle("Haptic feedback", isOn: $settings.hapticsEnabled)
                    .help("Play trackpad haptics on gestures and button presses.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func thresholdSlider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        format: String,
        help: String
    ) -> some View {
        LabeledContent(title) {
            HStack {
                Slider(value: value, in: range)
                    .accessibilityLabel(title)
                Text(String(format: format, value.wrappedValue))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 64, alignment: .trailing)
                    .accessibilityHidden(true)
            }
        }
        .help(help)
    }

    private func cgFloatBinding(_ keyPath: WritableKeyPath<GestureConfiguration, CGFloat>) -> Binding<Double> {
        Binding(
            get: { Double(settings.configuration[keyPath: keyPath]) },
            set: { settings.configuration[keyPath: keyPath] = CGFloat($0) }
        )
    }

    private func doubleBinding(_ keyPath: WritableKeyPath<GestureConfiguration, Double>) -> Binding<Double> {
        Binding(
            get: { settings.configuration[keyPath: keyPath] },
            set: { settings.configuration[keyPath: keyPath] = $0 }
        )
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
