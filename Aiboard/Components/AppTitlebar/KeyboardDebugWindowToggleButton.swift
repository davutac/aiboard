import SwiftUI

// MARK: - KeyboardDebugWindowToggleButton
struct KeyboardDebugWindowToggleButton: View {
    @Environment(\.floatingWindowManager) private var floatingWindowManager

    // MARK: - Body
    var body: some View {
        Button("Keyboard Debug", systemImage: "info.circle") {
            floatingWindowManager.toggle(
                .keyboardDebug,
                configuration: .keyboardDebugWindow
            ) { actions in
                KeyboardDebugWindowContent(hide: actions.hide)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .labelStyle(.iconOnly)
        .foregroundStyle(floatingWindowManager.isVisible(.keyboardDebug) ? .blue : .primary)
        .help(accessibilityLabel)
    }

    // MARK: - Text
    private var accessibilityLabel: String {
        floatingWindowManager.isVisible(.keyboardDebug)
            ? "Hide keyboard debug"
            : "Show keyboard debug"
    }
}
