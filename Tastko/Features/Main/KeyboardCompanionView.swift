import SwiftUI

// MARK: - Keyboard Companion
struct KeyboardCompanionView: View {
    @Environment(\.floatingWindowController) private var floatingWindowController
    @Environment(\.windowDimensions) private var dimensions
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var glassNamespace

    // MARK: - Body
    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                if let service = floatingWindowController.sentenceService {
                    if service.isGenerating {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 16, height: 16)
                            .padding(8)
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
                                maximumWidth: max(
                                    1,
                                    (dimensions.parentSize.width - (service.isGenerating ? 96 : 56))
                                        / 2
                                ),
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
                            .frame(
                                maxWidth: max(80, dimensions.parentSize.width - 70),
                                alignment: .leading
                            )
                            .padding(6)
                            .glassEffect()
                            .help(error)
                            .accessibilityLabel(error)
                    }
                }
            }
        }
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
}
