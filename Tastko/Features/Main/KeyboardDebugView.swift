import SwiftUI

// MARK: - KeyboardDebugView
struct KeyboardDebugView: View {
    @Environment(\.accessibilityService) private var accessibilityService
    @Environment(\.keyboardService) private var keyboardService

    let showsHeader: Bool

    @State private var snapshot = KeyboardTargetDebugSnapshot.unchecked

    // MARK: - Initialization
    init(showsHeader: Bool = true) {
        self.showsHeader = showsHeader
    }

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsHeader {
                Divider()

                header
            }

            VStack(alignment: .leading, spacing: 4) {
                KeyboardDebugRow("AX", value: snapshot.isAuthorized ? "Authorized" : "Denied")
                KeyboardDebugRow("Can send", value: snapshot.canSendKeystrokes ? "Yes" : "No")
                KeyboardDebugRow("Text input", value: snapshot.hasFocusedTextInput ? "Yes" : "No")
                KeyboardDebugRow("Route", value: snapshot.route?.debugTitle ?? "Unavailable")
                KeyboardDebugRow("App", value: applicationText)
                KeyboardDebugRow("Window", value: elementText(snapshot.focusedWindow))
                KeyboardDebugRow("Element", value: elementText(snapshot.focusedElement))
                KeyboardDebugRow("Cursor", value: cursorText)
                KeyboardDebugRow("Selected", value: selectedText)
                KeyboardDebugRow("Text", value: textPreview)
                KeyboardDebugRow(
                    "Before",
                    value: displayText(snapshot.focusedText?.textBeforeCursor(limit: 60))
                )
                KeyboardDebugRow(
                    "After",
                    value: displayText(snapshot.focusedText?.textAfterCursor(limit: 60))
                )
                KeyboardDebugRow("Last", value: lastKeyboardEventText)

                if let errorDescription = snapshot.errorDescription {
                    KeyboardDebugRow("Error", value: errorDescription)
                }

                KeyboardDebugRow(
                    "Updated",
                    value: snapshot.capturedAt.formatted(
                        date: .omitted,
                        time: .standard
                    )
                )
            }
            .font(.caption)
        }
        .task(id: keyboardService.isScreenLocked) {
            guard !keyboardService.isScreenLocked else {
                snapshot = .unchecked
                return
            }
            await refreshLoop()
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack(spacing: 8) {
            Label("Keyboard Debug", systemImage: "keyboard")
                .font(.headline)

            Spacer(minLength: 8)

            refreshButton
        }
    }

    private var refreshButton: some View {
        Button("Refresh", systemImage: "arrow.clockwise") {
            refresh()
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .accessibilityLabel("Refresh keyboard debug")
        .help("Refresh keyboard debug")
    }

    // MARK: - Text
    private var applicationText: String {
        guard let processIdentifier = snapshot.processIdentifier else {
            return "Unavailable"
        }

        let applicationName = snapshot.applicationName ?? "Unknown"

        return "\(applicationName) (pid \(processIdentifier))"
    }

    private var lastKeyboardEventText: String {
        if let lastError = keyboardService.lastError {
            return lastError.localizedDescription
        }

        guard let lastReceipt = keyboardService.lastReceipt else {
            return "None"
        }

        return lastReceipt.summary
    }

    private var cursorText: String {
        guard let focusedText = snapshot.focusedText else {
            return "Unavailable"
        }

        guard let location = focusedText.selectedRange?.location else {
            return "Unknown"
        }

        let length = focusedText.selectedRange?.length ?? 0
        let characterCount = focusedText.numberOfCharacters.map { " / \($0)" } ?? ""

        return length == 0
            ? "\(location)\(characterCount)"
            : "\(location)-\(location + length)\(characterCount)"
    }

    private var selectedText: String {
        guard let selectedText = snapshot.focusedText?.selectedText else {
            return "None"
        }

        return displayText(selectedText)
    }

    private var textPreview: String {
        displayText(snapshot.focusedText?.textAroundCursor())
    }

    private func elementText(_ element: AccessibilityElementDebugInfo?) -> String {
        guard let element else {
            return "Unavailable"
        }

        let role = element.roleDescription ?? element.role ?? "Unknown"
        let title = element.title?.isEmpty == false ? element.title : nil
        let subrole = element.subrole?.isEmpty == false ? element.subrole : nil
        let suffix = [title, subrole]
            .compactMap { $0 }
            .joined(separator: " | ")

        return suffix.isEmpty ? role : "\(role) - \(suffix)"
    }

    private func displayText(_ text: String?) -> String {
        guard let text else {
            return "Unavailable"
        }

        return
            text
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\t", with: "\\t")
    }

    // MARK: - Refreshing
    private func refresh() {
        guard !keyboardService.isScreenLocked else {
            snapshot = .unchecked
            return
        }
        snapshot = accessibilityService.keyboardTargetDebugSnapshot()
    }

    private func refreshLoop() async {
        refresh()

        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(1))
            }
            catch {
                return
            }

            refresh()
        }
    }
}

// MARK: - KeyboardDebugRow
private struct KeyboardDebugRow: View {
    let title: String
    let value: String

    // MARK: - Initialization
    init(_ title: String, value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        LabeledContent(title) {
            Text(value)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
        }
    }
}

// MARK: - AccessibilityFocusRoute Debug
extension AccessibilityFocusRoute {
    fileprivate var debugTitle: String {
        switch self {
        case .textElement:
            "Text element"
        case .window:
            "Window fallback"
        case .application:
            "Application fallback"
        }
    }
}
