import SwiftUI

// MARK: - KeyboardLanguageCycleButton
struct KeyboardLanguageCycleButton: View {
    @Environment(\.keyboardLanguageService) private var keyboardLanguageService
    @Environment(\.soundService) private var soundService

    // MARK: - Body
    var body: some View {
        Button {
            soundService.play(.keyPress)
            keyboardLanguageService.selectNextLanguage()
        } label: {
            Text(title)
                .monospacedDigit()
        }
        .disabled(keyboardLanguageService.languages.isEmpty)
        .accessibilityLabel(helpText)
        .accessibilityHint("Switches to the next enabled keyboard language")
        .help(helpText)
        .onAppear {
            keyboardLanguageService.refresh()
        }
    }

    // MARK: - Text
    private var title: String {
        keyboardLanguageService.selectedLanguage?.shortTitle ?? "--"
    }

    private var helpText: String {
        guard let selectedLanguage = keyboardLanguageService.selectedLanguage else {
            return "Keyboard language"
        }

        return "Keyboard language: \(selectedLanguage.name)"
    }
}
