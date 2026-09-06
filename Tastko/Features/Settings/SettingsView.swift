import Defaults
import SwiftUI

// MARK: - SettingsView
@MainActor
struct SettingsView: View {
    let updateService: AppUpdateService
    @Default(.floatingWindowMinimumScale) private var minimumScale
    @Default(.textPredictionEnabled) private var textPredictionEnabled
    @Default(.pointerAutoHideEnabled) private var pointerAutoHideEnabled
    @Default(.pointerAutoHideDelay) private var pointerAutoHideDelay
    @Default(.hotCornerDwellDuration) private var hotCornerDwellDuration
    @Default(.experimentalLockScreenDisplay) private var experimentalLockScreenDisplay
    @Environment(\.floatingWindowController) private var floatingWindowController
    @Environment(\.textPredictionService) private var textPredictionService

    // MARK: - Body
    var body: some View {
        Form {
            LaunchAtLoginSettingsView()
            AppUpdateSettingsView(updateService: updateService)
            Section("Typing") {
                Toggle("Text prediction", isOn: $textPredictionEnabled)
                Text(textPredictionService.modelStatus)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(
                    "macOS suggests word completions and next words. On-device AI adds suggestions when needed."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            ButtonSoundSettingsView()
            Section("Floating Window") {
                Toggle("Automatically hide when the pointer is idle", isOn: $pointerAutoHideEnabled)
                Stepper(
                    value: $pointerAutoHideDelay,
                    in: PointerVisibilityPolicy.inactivityDelayRange,
                    step: 5
                ) {
                    LabeledContent("Hide after") {
                        Text(
                            "\(pointerAutoHideDelay, format: .number.precision(.fractionLength(0))) seconds"
                        )
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    }
                }
                .disabled(!pointerAutoHideEnabled)
                Text("Move the pointer to show the keyboard again.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Stepper(
                    value: $hotCornerDwellDuration,
                    in: PointerVisibilityPolicy.cornerDwellRange,
                    step: 0.5
                ) {
                    LabeledContent("Hot-corner dwell time") {
                        Text(
                            "\(hotCornerDwellDuration, format: .number.precision(.fractionLength(1))) seconds"
                        )
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    }
                }
                Text(
                    "Pause in any screen’s bottom-right corner to hide or show the keyboard. Leave the corner before triggering it again."
                )
                .font(.callout)
                .foregroundStyle(.secondary)

                Stepper(
                    value: minimumScaleBinding,
                    in: minimumScaleRange,
                    step: 0.05
                ) {
                    LabeledContent("Minimum keyboard scale") {
                        Text(minimumScale, format: .percent.precision(.fractionLength(0)))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                Text(
                    "Sets how small you can resize the keyboard. A larger minimum keeps keys easier to select."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            Section("Experimental") {
                Toggle("Show keyboard on lock screen", isOn: $experimentalLockScreenDisplay)
                    .disabled(floatingWindowController.isScreenLocked)
                Text(
                    "Use the keyboard while locked. Predictions stay off. Uses private macOS APIs that may stop working after an update; input acceptance depends on macOS."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                Text(floatingWindowController.lockScreenDisplayStatus)
                    .font(.callout)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 600)
        .onChange(of: textPredictionEnabled) {
            floatingWindowController.updatePredictionLifecycle()
        }
        .onChange(of: experimentalLockScreenDisplay) {
            floatingWindowController.updateLockScreenDisplay()
        }
    }

    // MARK: - Bindings
    private var minimumScaleRange: ClosedRange<Double> {
        let range = FloatingWindowDefaults.allowedMinimumKeyboardScaleRange
        return Double(range.lowerBound)...Double(range.upperBound)
    }

    private var minimumScaleBinding: Binding<Double> {
        Binding {
            minimumScale
        } set: { newValue in
            minimumScale = Double(
                CGFloat(newValue).clamped(
                    to: FloatingWindowDefaults.allowedMinimumKeyboardScaleRange
                )
            )
            floatingWindowController.updateSettings()
        }
    }
}

#Preview {
    SettingsView(updateService: AppUpdateService())
}
