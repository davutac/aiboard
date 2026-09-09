import SwiftUI

// MARK: - Keyboard Companion
struct KeyboardCompanionView: View {
    @Environment(\.floatingWindowController) private var floatingWindowController
    @Environment(\.windowDimensions) private var dimensions
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var glassNamespace

    // MARK: - Body
    var body: some View {
        GlassEffectContainer(spacing: KeyboardDesign.Metrics.companionSpacing) {
            HStack(spacing: KeyboardDesign.Metrics.companionSpacing) {
                if let service = floatingWindowController.sentenceService {
                    if service.isGenerating {
                        ProgressView()
                            .controlSize(.small)
                            .frame(
                                width: KeyboardDesign.Metrics.companionHeight,
                                height: KeyboardDesign.Metrics.companionHeight
                            )
                            .glassEffect()
                            .glassEffectID("loading", in: glassNamespace)
                            .glassEffectTransition(reduceMotion ? .identity : .matchedGeometry)
                            .accessibilityLabel("Generating sentence completions")
                    }
                    if !service.suggestions.isEmpty {
                        ForEach(Array(service.suggestions.enumerated()), id: \.offset) {
                            index,
                            suggestion in
                            SentenceSuggestionButton(
                                suggestion: suggestion,
                                index: index,
                                maximumWidth: suggestionWidth(service: service),
                                service: service
                            )
                            .glassEffectID(
                                index == 0 ? "completion" : "alternative",
                                in: glassNamespace
                            )
                            .glassEffectTransition(reduceMotion ? .identity : .matchedGeometry)
                            .transition(
                                reduceMotion ? .identity : .offset(x: -8).combined(with: .opacity)
                            )
                        }
                    }
                    else if let error = service.error {
                        Label(error, systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .frame(
                                maxWidth: availableContentWidth(service: service),
                                alignment: .leading
                            )
                            .frame(height: KeyboardDesign.Metrics.companionHeight)
                            .glassEffect()
                            .help(error)
                            .accessibilityLabel(error)
                    }
                }
            }
        }
        .frame(height: KeyboardDesign.Metrics.companionHeight)
        .environment(\.layoutDirection, .leftToRight)
        .animation(
            reduceMotion ? nil : .smooth(duration: 0.32),
            value: floatingWindowController.sentenceService?.suggestions
        )
        .animation(
            reduceMotion ? nil : .smooth(duration: 0.32),
            value: floatingWindowController.sentenceService?.isGenerating
        )
    }

    // MARK: - Layout
    private func availableContentWidth(service: SentenceCompletionService) -> CGFloat {
        let loadingWidth =
            service.isGenerating
            ? KeyboardDesign.Metrics.companionHeight + KeyboardDesign.Metrics.companionSpacing : 0
        return max(1, dimensions.parentSize.width - loadingWidth)
    }

    private func suggestionWidth(service: SentenceCompletionService) -> CGFloat {
        let count = max(1, service.suggestions.count)
        let spacing = CGFloat(count - 1) * KeyboardDesign.Metrics.companionSpacing
        return max(1, (availableContentWidth(service: service) - spacing) / CGFloat(count))
    }
}
