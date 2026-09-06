import AppKit

// MARK: - NativeWordPredicting
@MainActor
protocol NativeWordPredicting {
    func predictions(for input: PredictionInput) async -> [String]
}

// MARK: - NativeWordPredictionProvider
@MainActor
final class NativeWordPredictionProvider: NativeWordPredicting {
    // MARK: - Native Candidates
    func predictions(for input: PredictionInput) async -> [String] {
        guard !Task.isCancelled else { return [] }
        let checker = NSSpellChecker.shared
        // Orthography alone does not override candidate language detection for short
        // prefixes. This checker belongs to Tastko, not the external target app.
        checker.automaticallyIdentifiesLanguages = false
        guard checker.setLanguage(input.language) else {
            return dictionaryCompletions(for: input)
        }
        let tag = NSSpellChecker.uniqueSpellDocumentTag()
        defer { checker.closeSpellDocument(withTag: tag) }
        let words: [String] = await withCheckedContinuation { continuation in
            checker.requestCandidates(
                forSelectedRange: NSRange(location: input.context.utf16.count, length: 0),
                in: input.context,
                types: NSTextCheckingResult.CheckingType([.replacement, .correction]).rawValue,
                options: [
                    .orthography: NSOrthography.defaultOrthography(forLanguage: input.language),
                    .generateInlinePredictionsKey: true,
                ],
                inSpellDocumentWithTag: tag
            ) { _, candidates in
                // AppKit may call back off the main actor. Only immutable words leave
                // this callback; the service rejects cancelled and stale requests.
                continuation.resume(
                    returning: candidates.compactMap { candidate in
                        guard let replacement = candidate.replacementString else { return nil }
                        return input.nativeCandidate(
                            replacement: replacement,
                            range: candidate.range
                        )
                    }
                )
            }
        }
        guard !Task.isCancelled else { return [] }
        let validated = input.validated(words)
        guard validated.count < PredictionInput.maximumSuggestions else { return validated }
        return input.validated(validated + dictionaryCompletions(for: input))
    }

    // MARK: - Dictionary Fallback
    private func dictionaryCompletions(for input: PredictionInput) -> [String] {
        guard !input.prefix.isEmpty else { return [] }
        return NSSpellChecker.shared.completions(
            forPartialWordRange: NSRange(
                location: input.context.utf16.count - input.prefix.utf16.count,
                length: input.prefix.utf16.count
            ),
            in: input.context,
            language: input.language,
            inSpellDocumentWithTag: 0
        ) ?? []
    }
}
