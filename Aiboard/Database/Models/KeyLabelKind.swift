// MARK: - KeyLabelKind
nonisolated enum KeyLabelKind: String, CaseIterable, Codable, Hashable, Sendable {
    case text
    case symbol
}

// MARK: - KeyLabelKind Display
extension KeyLabelKind {
    nonisolated var displayTitle: String {
        switch self {
        case .text:
            "Text"
        case .symbol:
            "Symbol"
        }
    }
}
