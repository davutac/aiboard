import SwiftUI

// MARK: - WordSuggestionsView
struct WordSuggestionsView: View {
    let service: TextPredictionService

    // MARK: - Body
    var body: some View {
        ViewThatFits(in: .horizontal) {
            ForEach(Array(service.suggestions.indices.reversed()), id: \.self) { lastIndex in
                suggestionRow(count: lastIndex + 1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            suggestionRow(count: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: KeyboardDesign.Metrics.suggestionHeight)
    }

    // MARK: - Fitting Suggestions
    private func suggestionRow(count: Int) -> some View {
        HStack(spacing: KeyboardDesign.Metrics.rowSpacing) {
            ForEach(Array(service.suggestions.prefix(count).enumerated()), id: \.element) {
                index,
                word in
                WordSuggestionButton(word: word, index: index, service: service)
            }
        }
    }
}
