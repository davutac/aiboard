#if DEBUG
    import SwiftUI

    // MARK: - AI Debug View
    struct AIDebugView: View {
        let service: AIProviderService
        @State private var prompt = ""
        @State private var output = ""
        @State private var error: String?
        @State private var resultSummary: String?
        @State private var elapsed: TimeInterval?
        @State private var task: Task<Void, Never>?

        // MARK: - Selection
        private var selected: AIProviderSelection? {
            service.activeProvider.flatMap { service.selections[$0] }
        }

        // MARK: - Body
        var body: some View {
            VStack(alignment: .leading) {
                Label(
                    selected.map {
                        "\($0.provider.name) · \($0.modelID ?? "Choose a model") · \($0.optionID ?? "Default")"
                    } ?? "AI is off. Select a provider in AI Providers.",
                    systemImage: selected == nil ? "power" : "cpu"
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("ai.debug.selection")

                HStack(alignment: .top) {
                    GroupBox("Input") {
                        TextEditor(text: $prompt)
                            .font(.body)
                            .frame(maxHeight: .infinity)
                            .accessibilityIdentifier("ai.debug.input")
                    }
                    GroupBox("Output") {
                        ScrollView {
                            Text(output.isEmpty ? "No output yet" : output)
                                .font(.body)
                                .textSelection(.enabled)
                                .foregroundStyle(output.isEmpty ? Color.secondary : Color.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .accessibilityIdentifier("ai.debug.output")
                        }
                        .frame(maxHeight: .infinity)
                    }
                }
                .frame(maxHeight: .infinity)

                HStack {
                    Button("Generate", systemImage: "arrow.up", action: generate)
                        .keyboardShortcut(.return, modifiers: .command)
                        .disabled(
                            task != nil || selected == nil
                                || prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                                    .isEmpty
                        )
                        .accessibilityIdentifier("ai.debug.generate")
                    if task != nil {
                        Button("Cancel") { task?.cancel() }
                            .accessibilityIdentifier("ai.debug.cancel")
                        ProgressView().controlSize(.small)
                    }
                    Spacer()
                    if let elapsed {
                        Label(
                            "\(elapsed, format: .number.precision(.fractionLength(2))) s",
                            systemImage: "clock"
                        )
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    }
                }
                if let resultSummary {
                    Text(resultSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let error {
                    Text(error)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("ai.debug.error")
                }
            }
            .scenePadding()
            .onDisappear { task?.cancel() }
        }

        // MARK: - Generate
        private func generate() {
            let request = AIGenerationRequest(prompt: prompt)
            output = ""
            error = nil
            resultSummary = nil
            elapsed = nil
            task = Task { @MainActor in
                let start = Date()
                defer {
                    elapsed = Date().timeIntervalSince(start)
                    task = nil
                }
                do {
                    let result = try await service.generate(request)
                    output = result.text
                    resultSummary =
                        "\(result.selection.provider.name) · \(result.selection.modelID ?? "") · \(result.selection.optionID ?? "Default")"
                }
                catch { self.error = error.localizedDescription }
            }
        }
    }
#endif
