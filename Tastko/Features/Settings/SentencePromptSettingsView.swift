import Defaults
import FoundationModels
import SwiftUI

// MARK: - Sentence Prompt Settings
struct SentencePromptSettingsView: View {
    @Default(.sentenceCompletionSystemPrompt) private var customPrompt
    @Environment(\.floatingWindowController) private var floatingWindowController

    @State private var promptTokens: Int?
    @State private var promptLimit = AppleCompletionBudget.instructionLimit(
        for: SystemLanguageModel.default.contextSize
    )

    // MARK: - Body
    var body: some View {
        Section {
            TextField(
                "Sentence completion system prompt",
                text: $customPrompt,
                prompt: Text(SentenceCompletionPrompt.instructions),
                axis: .vertical
            )
            .font(.body)
            .textFieldStyle(.plain)
            .labelsHidden()
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("Sentence completion system prompt")
            .accessibilityHint("Leave empty to use the default prompt")
            .accessibilityIdentifier("ai.sentence-system-prompt")

            if let promptTokens {
                Text("\(promptTokens) / \(promptLimit) prompt tokens")
                    .font(.caption)
                    .foregroundStyle(promptTokens > promptLimit ? Color.red : Color.secondary)
                if promptTokens > promptLimit {
                    Text("Shorten this prompt or reset to default to resume suggestions.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            HStack {
                Button("Use default as starting point") {
                    customPrompt = SentenceCompletionPrompt.instructions
                }
                Spacer()
                Button("Reset to default") { customPrompt = "" }
                    .disabled(customPrompt.isEmpty)
            }
        } header: {
            Text("Sentence completion prompt")
        } footer: {
            Text(
                "Leave empty to use the default prompt. Changes save automatically and apply to all AI providers. Completions must still preserve your typed text."
            )
        }
        .task(id: customPrompt) {
            promptTokens = nil
            do {
                try await Task.sleep(for: .milliseconds(250))
                let model = SystemLanguageModel.default
                let count = try await model.tokenCount(
                    for: Instructions(SentenceCompletionPrompt.resolvedInstructions(customPrompt))
                )
                try Task.checkCancellation()
                promptLimit = AppleCompletionBudget.instructionLimit(for: model.contextSize)
                promptTokens = count
            }
            catch {}
        }
        .onChange(of: customPrompt) {
            floatingWindowController.sentenceService?.instructionsDidChange()
        }
    }
}
