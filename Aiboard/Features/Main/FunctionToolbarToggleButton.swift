import SwiftUI

// MARK: - FunctionToolbarToggleButton
struct FunctionToolbarToggleButton: View {
    @Environment(\.floatingWindowController) private var floatingWindowController
    @Environment(\.soundService) private var soundService

    // MARK: - Body
    var body: some View {
        Button {
            soundService.play(.keyPress)
            floatingWindowController.toggleFunctionToolbar()
        } label: {
            Image(
                systemName: floatingWindowController.isFunctionToolbarVisible
                    ? "chevron.up" : "chevron.down"
            )
        }
        .help(label)
        .accessibilityLabel(label)
        .accessibilityValue(floatingWindowController.isFunctionToolbarVisible ? "Shown" : "Hidden")
        .accessibilityIdentifier("function-toolbar-toggle")
    }

    private var label: String {
        floatingWindowController.isFunctionToolbarVisible
            ? "Hide function toolbar" : "Show function toolbar"
    }
}
