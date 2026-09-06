import SwiftUI

// MARK: - WordSuggestionButton
struct WordSuggestionButton: View {
    let word: String
    let index: Int
    let service: TextPredictionService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.soundService) private var soundService

    @State private var pressedButton: KeyMouseButton?
    @State private var releasedButton: KeyMouseButton?
    @State private var isPressActive = false
    @State private var isHovered = false

    // MARK: - Body
    var body: some View {
        suggestionLabel
            .font(KeyboardDesign.Typography.suggestion)
            .foregroundStyle(KeyboardDesign.Palette.label)
            .lineLimit(1)
            .padding(.horizontal, KeyboardDesign.Metrics.suggestionInset)
            .frame(height: KeyboardDesign.Metrics.suggestionHeight)
            .background {
                KeycapSurface(
                    shape: RoundedRectangle(cornerRadius: KeyboardDesign.Metrics.keyRadius),
                    isPressed: pressedButton == .left,
                    isHovered: isHovered
                )
            }
            .scaleEffect(pressedButton == .left ? 0.97 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: pressedButton)
            .overlay {
                KeyMouseEventView(
                    pressedButton: $pressedButton,
                    releasedButton: $releasedButton,
                    allowsDragTracking: false,
                    mousePressed: beginPress,
                    mouseReleasedInside: releasePress,
                    mouseCancelled: cancelPress,
                    editingDragChanged: { _ in },
                    editingDragEnded: { _ in }
                )
                .accessibilityHidden(true)
            }
            .onHover { isHovered = $0 }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Insert \(word)")
            .accessibilityIdentifier("prediction-\(index)")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                soundService.play(.keyPress)
                if let choice = service.choice(for: word) { service.accept(choice) }
            }
            .onDisappear(perform: cancelPress)
    }

    // MARK: - Completion Highlight
    private var suggestionLabel: Text {
        guard !service.typedPrefix.isEmpty else {
            return Text(word).font(KeyboardDesign.Typography.suggestionCompletion)
        }
        guard
            let prefixRange = word.range(
                of: service.typedPrefix,
                options: [.anchored, .caseInsensitive]
            )
        else { return Text(word) }
        let prefix = Text(String(word[..<prefixRange.upperBound]))
            .font(KeyboardDesign.Typography.suggestionPrefix)
            .foregroundStyle(KeyboardDesign.Palette.secondaryLabel)
        let completion = Text(String(word[prefixRange.upperBound...]))
            .font(KeyboardDesign.Typography.suggestionCompletion)
        return Text("\(prefix)\(completion)")
    }

    // MARK: - Press Lifecycle
    private func beginPress(_ button: KeyMouseButton) {
        guard button == .left, !isPressActive else { return }
        isPressActive = true
        soundService.play(.keyPress)
        guard let choice = service.choice(for: word) else { return }
        service.accept(choice)
    }

    // MARK: - Release
    private func releasePress(_ button: KeyMouseButton) {
        guard button == .left else { return }
        cancelPress()
    }

    // MARK: - Cancellation
    private func cancelPress() {
        isPressActive = false
    }
}
