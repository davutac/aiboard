import Foundation

// MARK: - PredictionInput
nonisolated struct PredictionInput: Equatable, Sendable {
    static let maximumSuggestions = 8
    let context: String
    let prefix: String
    let language: String
    let isAtEnd: Bool

    // MARK: - Cursor Context
    init?(text: String, range: AccessibilityTextRange, language: String) {
        guard range.isInsertionPoint, range.location >= 0,
            range.location <= text.utf16.count,
            let cursor = String.Index(utf16Offset: range.location, in: text)
                .samePosition(in: text),
            cursor == text.endIndex || text.indices.contains(cursor)
        else { return nil }

        // Do not complete into the middle/start of an existing word.
        guard cursor == text.endIndex || !Self.isWordCharacter(text[cursor]) else {
            return nil
        }

        let preceding = text[..<cursor]
        let prefix = String(preceding.reversed().prefix(while: Self.isWordCharacter).reversed())
        guard prefix.count <= 64 else { return nil }
        self.context = String(preceding.suffix(512))
        self.prefix = prefix
        self.language = language
        self.isAtEnd = cursor == text.endIndex
    }

    // MARK: - Candidate Validation
    func validated(_ candidates: [String]) -> [String] {
        var seen = Set<String>()
        let locale = Locale(identifier: language)
        return candidates.compactMap { candidate in
            guard var word = Self.normalizedWord(candidate) else { return nil }

            if !prefix.isEmpty {
                // Case changes are allowed in model output, but never rewrite what was typed.
                guard
                    let match = word.range(
                        of: prefix,
                        options: [.anchored, .caseInsensitive],
                        locale: locale
                    )
                else { return nil }
                word = prefix + word[match.upperBound...]
                guard word.count > prefix.count else { return nil }
            }
            guard seen.insert(word.lowercased(with: locale)).inserted else { return nil }
            return word
        }
    }

    // MARK: - Insertion
    func insertion(for word: String) -> String? {
        guard let validated = validated([word]).first else { return nil }
        return acceptance(for: validated)?.text
    }

    // MARK: - Visible Suggestion Acceptance
    func acceptance(for candidate: String) -> PredictionInsertion? {
        guard let word = Self.normalizedWord(candidate) else { return nil }
        let suffix = isAtEnd ? " " : ""
        if prefix.isEmpty {
            return PredictionInsertion(text: leadingSpace + word + suffix, deleteBackwardCount: 0)
        }
        if let match = word.range(
            of: prefix,
            options: [.anchored, .caseInsensitive],
            locale: Locale(identifier: language)
        ) {
            return PredictionInsertion(
                text: String(word[match.upperBound...]) + suffix,
                deleteBackwardCount: 0
            )
        }
        // A clicked word may outlive the prefix that originally produced it.
        // Replace only the current word fragment, never preceding words.
        return PredictionInsertion(text: word + suffix, deleteBackwardCount: prefix.count)
    }

    // MARK: - Punctuation Spacing
    private var leadingSpace: String {
        guard prefix.isEmpty, let preceding = context.last,
            Self.isSentencePunctuation(preceding)
        else { return "" }
        return " "
    }

    // MARK: - Sentence Punctuation
    static func isSentencePunctuation(_ character: Character) -> Bool {
        ",.!?;:…".contains(character)
    }

    // MARK: - Word Validation
    private static func normalizedWord(_ candidate: String) -> String? {
        let word = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping
        guard !word.isEmpty, word.count <= 64,
            word.first?.isLetter == true, word.last?.isLetter == true,
            word.allSatisfy(isWordCharacter)
        else { return nil }
        return word
    }

    // MARK: - Native Candidate Ranges
    func nativeCandidate(replacement: String, range: NSRange) -> String? {
        let cursor = context.utf16.count
        let wordRange = NSRange(location: cursor - prefix.utf16.count, length: prefix.utf16.count)
        let word: String
        if range == wordRange {
            word = replacement
        }
        else if range == NSRange(location: cursor, length: 0) {
            word = prefix + replacement
        }
        else {
            // Ignore corrections to earlier text and replacements spanning multiple words.
            return nil
        }
        return validated([word]).first
    }

    // MARK: - Word Boundaries
    private static func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character == "'" || character == "’" || character == "-"
    }
}

// MARK: - PredictionInsertion
nonisolated struct PredictionInsertion: Equatable, Sendable {
    let text: String
    let deleteBackwardCount: Int
}
