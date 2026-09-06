import Foundation

// MARK: - PredictionTypingEdit
enum PredictionTypingEdit: Equatable {
    case insert(String)
    case backspace
    case unchanged
    case reset
}

// MARK: - PredictionTypingBuffer
struct PredictionTypingBuffer {
    private(set) var text = ""
    private var target: FocusedKeyboardTarget?
    private var inputSource: String?
    private(set) var session = UUID()
    private var revision = 0
    private var expectedCursor: Int?
    private var pendingCursors: Set<Int> = []
    private var pendingUntil: ContinuousClock.Instant?

    // MARK: - Focus and Cursor Validation
    mutating func observe(
        target: FocusedKeyboardTarget,
        selection: AccessibilityTextRange?,
        inputSource: String?,
        now: ContinuousClock.Instant = .now
    ) {
        if self.target?.hasSameFocus(as: target) != true || self.inputSource != inputSource {
            startSession(target: target, inputSource: inputSource, cursor: selection?.location)
        }
        guard selection?.isInsertionPoint != false else {
            reset()
            return
        }
        if let cursor = selection?.location {
            if cursor == expectedCursor {
                pendingCursors.removeAll()
                pendingUntil = nil
            }
            else if !(pendingUntil.map { now < $0 } == true && pendingCursors.contains(cursor)) {
                startSession(target: target, inputSource: inputSource, cursor: cursor)
            }
        }
        else if expectedCursor != nil {
            // Losing previously available cursor information also loses our anchor.
            startSession(target: target, inputSource: inputSource, cursor: nil)
        }
    }

    // MARK: - Posted Input
    mutating func apply(_ edit: PredictionTypingEdit, now: ContinuousClock.Instant = .now) {
        guard target != nil else { return }
        let delta: Int
        switch edit {
        case .insert(let inserted):
            guard !inserted.isEmpty else { return }
            guard !inserted.contains(where: { $0.isNewline || $0 == "\t" }) else {
                reset()
                return
            }
            text = String((text + inserted).suffix(512))
            delta = inserted.utf16.count
        case .backspace:
            guard let last = text.last else {
                reset()
                return
            }
            delta = -String(last).utf16.count
            text.removeLast()
        case .unchanged: return
        case .reset:
            reset()
            return
        }
        revision += 1
        if let cursor = expectedCursor {
            pendingCursors.insert(cursor)
            expectedCursor = max(0, cursor + delta)
            pendingUntil = now + .milliseconds(150)
        }
    }

    // MARK: - Context
    func context(language: String) -> PredictionContext? {
        guard let target, !text.isEmpty else { return nil }
        let range = AccessibilityTextRange(location: text.utf16.count, length: 0)
        guard let input = PredictionInput(text: text, range: range, language: language)
        else { return nil }
        return PredictionContext(
            target: target,
            value: FocusedTextValue(
                text: text,
                selectedText: nil,
                selectedRange: range,
                numberOfCharacters: text.utf16.count
            ),
            input: input,
            source: .typingSession(session, revision: revision)
        )
    }

    // MARK: - Reset
    private mutating func startSession(
        target: FocusedKeyboardTarget,
        inputSource: String?,
        cursor: Int?
    ) {
        reset()
        self.target = target
        self.inputSource = inputSource
        expectedCursor = cursor
    }

    mutating func reset() {
        text = ""
        target = nil
        inputSource = nil
        expectedCursor = nil
        pendingCursors.removeAll()
        pendingUntil = nil
        session = UUID()
        revision = 0
    }
}
