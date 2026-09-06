import SwiftUI

// MARK: - SystemAccessibilityKeyboardButton
struct SystemAccessibilityKeyboardButton: View {
    @Environment(\.accessibilityService) private var accessibilityService
    @State private var toggleError: String?
    @State private var isToggling = false

    // MARK: - Body
    var body: some View {
        Button("Toggle macOS Accessibility Keyboard", systemImage: "keyboard") {
            toggleKeyboard()
        }
        .labelStyle(.iconOnly)
        .accessibilityIdentifier("toggle-system-accessibility-keyboard")
        .help("Toggle macOS Accessibility Keyboard")
        .alert(
            "Couldn’t Toggle Accessibility Keyboard",
            isPresented: Binding(
                get: { toggleError != nil },
                set: { if !$0 { toggleError = nil } }
            )
        ) {
            Button("Open Keyboard Settings") {
                SystemAccessibilityKeyboard.openSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(toggleError ?? "")
        }
    }

    // MARK: - Toggle Keyboard
    private func toggleKeyboard() {
        guard !isToggling else { return }
        guard accessibilityService.refreshAuthorizationStatus() else {
            accessibilityService.requestAuthorization()
            return
        }
        isToggling = true
        Task { @MainActor in
            defer { isToggling = false }
            do {
                try await SystemAccessibilityKeyboard.toggle()
            }
            catch {
                toggleError = error.localizedDescription
            }
        }
    }
}
