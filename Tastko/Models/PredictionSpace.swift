// MARK: - PredictionSpace
struct PredictionSpace {
    let before: PredictionContext
    let expectedText: String
    var awaitingInsertion = true

    // MARK: - Accepted Prediction
    init?(insertion: PredictionInsertion, context: PredictionContext) {
        guard context.source == .accessibility, context.input.isAtEnd,
            insertion.text.hasSuffix(" "),
            let text = context.value.text
        else { return nil }
        before = context
        expectedText = String(text.dropLast(insertion.deleteBackwardCount)) + insertion.text
    }
}
