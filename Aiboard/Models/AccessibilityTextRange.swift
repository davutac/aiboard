// MARK: - AccessibilityTextRange
nonisolated struct AccessibilityTextRange: Hashable, Sendable {
    let location: Int
    let length: Int

    var upperBound: Int {
        location + length
    }

    var isInsertionPoint: Bool {
        length == 0
    }
}
