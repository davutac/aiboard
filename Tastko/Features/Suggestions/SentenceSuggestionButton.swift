import SwiftUI

// MARK: - Sentence Suggestion Button
struct SentenceSuggestionButton: View {
    let suggestion: String
    let index: Int
    let maximumWidth: CGFloat
    let service: SentenceCompletionService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressedButton: KeyMouseButton?

    // MARK: - Body
    var body: some View {
        Text("…" + suggestion.trimmingCharacters(in: .whitespaces))
            .contentTransition(reduceMotion ? .identity : .opacity)
            .font(.system(size: 13, weight: .medium))
            .lineLimit(1)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 12)
            .frame(maxWidth: maximumWidth, alignment: .leading)
            .frame(height: KeyboardDesign.Metrics.companionHeight)
            .glassEffect(.regular.interactive())
            .overlay {
                // Match word-key input: never create SwiftUI keyboard-focus proxies in this panel.
                KeyMouseEventView(
                    pressedButton: $pressedButton,
                    mousePressed: { if $0 == .left { accept() } },
                    mouseReleasedInside: { _ in pressedButton = nil },
                    mouseCancelled: { pressedButton = nil }
                )
                .accessibilityHidden(true)
            }
            .help("Insert \(suggestion)")
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Insert completion \(suggestion)")
            .accessibilityIdentifier("sentence-completion-\(index)")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { accept() }
    }

    // MARK: - Acceptance
    private func accept() {
        if service.accept(suggestion) { SoundService.shared.play(.keyPress) }
    }
}
