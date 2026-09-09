import Foundation
import Observation

// MARK: - Sentence Completion Service
@Observable @MainActor
final class SentenceCompletionService {
    private(set) var suggestions: [String] = []
    private(set) var isGenerating = false
    private(set) var error: String?
    @ObservationIgnored private var scheduledRequest: Task<Void, Never>?
    @ObservationIgnored private var requests: [Int: Task<Void, Never>] = [:]
    @ObservationIgnored private var nextRequestID = 0
    @ObservationIgnored private var newestPublishedID = -1
    @ObservationIgnored private var revision = 0
    @ObservationIgnored private var running = false
    @ObservationIgnored private var displayedContext: PredictionContext?
    @ObservationIgnored private var lastContext: PredictionContext?
    @ObservationIgnored private var lastSelection: AIProviderSelection?
    @ObservationIgnored private let context: () -> PredictionContext?
    @ObservationIgnored private let wordSuggestions: (PredictionContext) -> [String]
    @ObservationIgnored private let selection: () -> AIProviderSelection?
    @ObservationIgnored private let generate: (String) async throws -> String
    @ObservationIgnored private let insert: (String, PredictionContext) -> Bool
    @ObservationIgnored private let minimumInterval: Duration?
    @ObservationIgnored private var lastStarted: ContinuousClock.Instant?
    @ObservationIgnored private var requestedContext: PredictionContext?

    // MARK: - Initialization
    init(
        minimumInterval: Duration? = nil,
        context: @escaping () -> PredictionContext?,
        wordSuggestions: @escaping (PredictionContext) -> [String] = { _ in [] },
        selection: @escaping () -> AIProviderSelection?,
        generate: @escaping (String) async throws -> String,
        insert: @escaping (String, PredictionContext) -> Bool
    ) {
        self.minimumInterval = minimumInterval
        self.context = context
        self.wordSuggestions = wordSuggestions
        self.selection = selection
        self.generate = generate
        self.insert = insert
    }

    // MARK: - Lifecycle
    func start() {
        guard !running else { return }
        running = true
        observe()
    }

    func stop() {
        running = false
        cancel()
        lastContext = nil
        lastSelection = nil
    }

    // MARK: - Instruction Changes
    func instructionsDidChange() {
        cancel()
        lastContext = nil
        guard running else { return }
        update(context: context(), selection: selection())
    }

    private func observe() {
        guard running else { return }
        let snapshot = withObservationTracking {
            (context(), selection())
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.observe() }
        }
        update(context: snapshot.0, selection: snapshot.1)
    }

    // MARK: - Generation
    private func update(context next: PredictionContext?, selection selected: AIProviderSelection?)
    {
        guard next != lastContext || selected != lastSelection else { return }
        let previous = lastContext
        let providerChanged = selected != lastSelection
        lastContext = next
        lastSelection = selected
        guard let next, selected != nil, Self.canComplete(next) else {
            cancel()
            return
        }
        if providerChanged || previous.map({ !Self.canContinue(from: $0, to: next) }) == true {
            cancel()
        }
        else if let displayedContext {
            suggestions = suggestions.compactMap { suffix in
                let completed = displayedContext.input.context + suffix
                guard completed.hasPrefix(next.input.context) else { return nil }
                let remaining = String(completed.dropFirst(next.input.context.count))
                return remaining.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil : remaining
            }
            self.displayedContext = suggestions.isEmpty ? nil : next
        }
        error = nil
        schedule()
    }

    private static func canComplete(_ context: PredictionContext) -> Bool {
        context.input.isAtEnd && context.input.context.filter(\.isLetter).count >= 3
    }

    private static func canContinue(from previous: PredictionContext, to current: PredictionContext)
        -> Bool
    {
        if let before = previous.value.text, let after = current.value.text,
            !after.hasPrefix(before)
        {
            return false
        }
        return current.hasSameSession(as: previous)
            && current.input.language == previous.input.language
            && current.input.isAtEnd
            && current.input.context.hasPrefix(previous.input.context)
    }

    // MARK: - Request Scheduling
    private func schedule() {
        guard running, scheduledRequest == nil, requests.count < 5,
            let next = lastContext, let selected = lastSelection,
            Self.canComplete(next), next != requestedContext
        else { return }
        let interval =
            minimumInterval ?? (selected.provider == .apple ? .milliseconds(500) : .seconds(2))
        let deadline = lastStarted.map { $0.advanced(by: interval) } ?? .now
        let token = revision
        scheduledRequest = Task { [weak self] in
            do { try await Task.sleep(until: deadline, clock: .continuous) }
            catch { return }
            guard let self, self.revision == token, !Task.isCancelled else { return }
            self.scheduledRequest = nil
            guard let current = self.context(), Self.canComplete(current),
                current != self.requestedContext, self.selection() == selected
            else { return }
            self.launch(context: current, selection: selected)
        }
    }

    // MARK: - Concurrent Requests
    private func launch(context current: PredictionContext, selection selected: AIProviderSelection)
    {
        let id = nextRequestID
        nextRequestID += 1
        let token = revision
        requestedContext = current
        lastStarted = .now
        requests[id] = Task { [weak self] in
            guard let self else { return }
            defer {
                self.requests[id] = nil
                self.updateGenerating()
                self.schedule()
            }
            do {
                try Task.checkCancellation()
                let output = try await self.generate(
                    SentenceCompletionPrompt.input(
                        current.input,
                        wordSuggestions: self.wordSuggestions(current)
                    )
                )
                try Task.checkCancellation()
                guard self.revision == token, id > self.newestPublishedID,
                    let latest = self.context(), self.selection() == selected,
                    Self.canContinue(from: current, to: latest)
                else { return }
                let candidates = Self.completions(from: output, input: latest.input.context)
                guard !candidates.isEmpty else {
                    if self.suggestions.isEmpty && latest == current {
                        self.error = "No completion available"
                    }
                    return
                }
                self.cancelOlderRequests(than: id)
                self.suggestions = candidates
                self.displayedContext = latest
                self.error = nil
            }
            catch {
                guard self.revision == token, !Task.isCancelled, id > self.newestPublishedID else {
                    return
                }
                self.error = error.localizedDescription
            }
        }
        updateGenerating()
    }

    // MARK: - Result Ordering
    private func cancelOlderRequests(than id: Int) {
        newestPublishedID = id
        for (olderID, request) in requests where olderID < id { request.cancel() }
    }

    private func updateGenerating() {
        isGenerating = requests.values.contains { !$0.isCancelled }
    }

    private func cancel() {
        revision += 1
        scheduledRequest?.cancel()
        scheduledRequest = nil
        for request in requests.values { request.cancel() }
        requestedContext = nil
        suggestions = []
        displayedContext = nil
        isGenerating = false
        error = nil
    }

    // MARK: - Insertion
    @discardableResult
    func accept(_ suggestion: String) -> Bool {
        guard suggestions.contains(suggestion), let displayedContext,
            context() == displayedContext, selection() == lastSelection
        else { return false }
        let accepted = insert(suggestion, displayedContext)
        cancel()
        requestedContext = lastContext
        return accepted
    }

    // MARK: - Response Validation
    static func completions(from output: String, input: String) -> [String] {
        guard let data = output.data(using: .utf8),
            let candidates = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        var seen = Set<String>()
        return Array(
            candidates.compactMap { candidate in
                guard candidate.hasPrefix(input) else { return nil }
                let suffix = String(candidate.dropFirst(input.count))
                guard !suffix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    suffix.count <= 240, !suffix.contains(where: { $0.isNewline }),
                    !suffix.unicodeScalars.contains(where: {
                        CharacterSet.controlCharacters.contains($0)
                    }),
                    seen.insert(suffix).inserted
                else { return nil }
                return suffix
            }.prefix(2)
        )
    }
}
