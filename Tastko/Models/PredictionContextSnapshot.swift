// MARK: - PredictionContextSnapshot
enum PredictionContextSnapshot {
    case readable(PredictionContext)
    case unreadable(FocusedKeyboardTarget, selection: AccessibilityTextRange?)
    case ineligible

    // MARK: - Accessibility Text Interpretation
    init(
        target: FocusedKeyboardTarget,
        value: FocusedTextValue,
        language: String,
        isValueSettable: Bool
    ) {
        guard value.selectedText == nil, value.selectedRange?.isInsertionPoint != false else {
            self = .ineligible
            return
        }
        if !isValueSettable {
            // Read-only surfaces can expose display text and a placeholder selection
            // rather than editable text and an insertion cursor.
            self = .unreadable(target, selection: nil)
            return
        }
        guard let text = value.text, let range = value.selectedRange else {
            self = .unreadable(target, selection: value.selectedRange)
            return
        }
        guard let input = PredictionInput(text: text, range: range, language: language) else {
            self = .ineligible
            return
        }
        self = .readable(PredictionContext(target: target, value: value, input: input))
    }
}
