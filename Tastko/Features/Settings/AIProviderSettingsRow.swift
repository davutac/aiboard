import SwiftUI

// MARK: - Provider Row
struct AIProviderSettingsRow: View {
    let service: AIProviderService
    let provider: AIProviderID

    // MARK: - Provider State
    private var selection: AIProviderSelection {
        service.selections[provider] ?? AIProviderSelection(provider: provider)
    }
    private var status: AIProviderStatus { service.statuses[provider] ?? AIProviderStatus() }
    private var model: AIModelDescriptor? { status.models.first { $0.id == selection.modelID } }

    private var statusLabel: String {
        if status.error != nil { return "Unavailable" }
        return status.accountDescription ?? "Not checked"
    }

    // MARK: - Body
    var body: some View {
        Section {
            LabeledContent("Status") {
                HStack {
                    if status.isRefreshing {
                        ProgressView().controlSize(.mini)
                    }
                    Text(statusLabel)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .textSelection(.enabled)
                }
            }
            if selection.modelID == nil
                || selection.modelID == AppleFoundationModelProvider.modelID
            {
                LabeledContent("Model", value: AppleFoundationModelProvider.modelName)
                    .accessibilityIdentifier("ai.apple.model")
            }
            else {
                modelPicker
            }
            if model?.option != nil || selection.optionID != nil {
                optionPicker
            }
            if let error = status.error {
                Text(error).foregroundStyle(.red).textSelection(.enabled)
            }
            if status.isCached {
                Text("Showing last successful model catalog.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let saved = selection.modelID, model == nil {
                Text("Saved model \(saved) is unavailable. Choose a model to generate text.")
                    .font(.callout).foregroundStyle(.orange)
            }
            configuration
        } header: {
            HStack {
                Image(systemName: "apple.intelligence")
                    .frame(width: 16, height: 16)
                    .accessibilityHidden(true)
                Text(provider.name)
            }
        }
    }

    // MARK: - Configuration
    private var configuration: some View {
        LabeledContent("Configuration") {
            HStack {
                if status.error != nil {
                    Button("System Settings…") {
                        NSWorkspace.shared.open(
                            URL(filePath: "/System/Applications/System Settings.app")
                        )
                    }
                }
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task { await service.refreshProvider(provider) }
                }
                .disabled(status.isRefreshing)
            }
        }
    }

    // MARK: - Model Picker
    private var modelPicker: some View {
        Picker("Model", selection: selectionBinding(\.modelID)) {
            Text("Choose a model").tag(nil as String?)
            if let saved = selection.modelID, model == nil {
                Text("\(saved) — unavailable").tag(Optional(saved))
            }
            ForEach(status.models) { model in
                Text(model.name).tag(Optional(model.id))
            }
        }
        .accessibilityLabel("\(provider.name) model")
        .accessibilityIdentifier("ai.\(provider.rawValue).model")
    }

    // MARK: - Reasoning Picker
    private var optionPicker: some View {
        Picker(model?.option?.name ?? "Option", selection: selectionBinding(\.optionID)) {
            Text("Default").tag(nil as String?)
            if let saved = selection.optionID,
                !(model?.option?.choices.contains { $0.id == saved } ?? false)
            {
                Text("\(saved) — unavailable").tag(Optional(saved))
            }
            ForEach(model?.option?.choices ?? []) { choice in
                Text(choice.name).tag(Optional(choice.id))
            }
        }
        .disabled(model?.option == nil && selection.optionID == nil)
        .accessibilityLabel("\(provider.name) \(model?.option?.name ?? "option")")
        .accessibilityIdentifier("ai.\(provider.rawValue).option")
    }

    // MARK: - Selection Binding
    private func selectionBinding(
        _ keyPath: WritableKeyPath<AIProviderSelection, String?>
    ) -> Binding<String?> {
        Binding {
            selection[keyPath: keyPath]
        } set: { value in
            var updated = selection
            updated[keyPath: keyPath] = value
            service.updateSelection(updated)
        }
    }

}
