import SwiftUI

// MARK: - Provider Row
struct AIProviderSettingsRow: View {
    let service: AIProviderService
    let provider: AIProviderID
    @State private var pathDraft = ""
    @State private var showingDetails = false

    // MARK: - Provider State
    private var selection: AIProviderSelection {
        service.selections[provider] ?? AIProviderSelection(provider: provider)
    }
    private var status: AIProviderStatus { service.statuses[provider] ?? AIProviderStatus() }
    private var model: AIModelDescriptor? { status.models.first { $0.id == selection.modelID } }

    private var statusLabel: String {
        if provider == .apple {
            if status.error != nil { return "Unavailable" }
            return status.accountDescription ?? "Not checked"
        }
        return status.accountDescription ?? status.authentication.label
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
            if provider == .apple,
                selection.modelID == nil
                    || selection.modelID == AppleFoundationModelProvider.modelID
            {
                LabeledContent("Model", value: AppleFoundationModelProvider.modelName)
                    .accessibilityIdentifier("ai.apple.model")
            }
            else {
                modelPicker
            }
            if provider.usesCLI || model?.option != nil || selection.optionID != nil {
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
                Group {
                    if provider == .apple {
                        Image(systemName: "apple.intelligence")
                    }
                    else {
                        Image("AI-\(provider.rawValue)").resizable().scaledToFit()
                    }
                }
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)
                Text(provider.name)
                if provider.usesCLI, let version = status.version {
                    Text("v\(version)").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .onAppear { pathDraft = selection.executableOverride }
        .onChange(of: selection.executableOverride) { pathDraft = selection.executableOverride }
    }

    // MARK: - Configuration
    private var configuration: some View {
        LabeledContent("Configuration") {
            if provider.usesCLI {
                Button("Details…") { showingDetails = true }
                    .accessibilityLabel("\(provider.name) details and setup")
                    .popover(isPresented: $showingDetails) { details }
            }
            else {
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

    // MARK: - Reasoning or Variant Picker
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

    // MARK: - Setup Popover
    private var details: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(provider.name).font(.headline)
                Spacer()
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task { await service.refreshProvider(provider) }
                }.disabled(status.isRefreshing)
            }
            if provider == .claude {
                Text(
                    "Models come from Tastko’s bundled catalog. Availability depends on your Claude account."
                )
                .font(.callout).foregroundStyle(.secondary)
            }
            TextField("Executable override", text: $pathDraft, prompt: Text("Automatic discovery"))
                .onSubmit(savePath)
                .accessibilityIdentifier("ai.\(provider.rawValue).path")
            HStack {
                Button("Apply Path", action: savePath).disabled(
                    pathDraft == selection.executableOverride
                )
                Button("Choose…", action: chooseExecutable)
                Button("Use Automatic") {
                    pathDraft = ""
                    savePath()
                }
            }
            if let executable = status.executable {
                Text(executable)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Divider()
            Link("Install \(provider.name)", destination: provider.website)
            if let command = provider.loginCommand {
                Text("Sign in using Terminal: \(command)")
                    .font(.callout).textSelection(.enabled)
            }
        }
        .scenePadding().frame(width: 390)
    }

    // MARK: - Save Executable Path
    private func savePath() {
        var updated = selection
        updated.executableOverride = pathDraft
        service.updateSelection(updated)
    }

    // MARK: - Choose Executable
    private func chooseExecutable() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.prompt = "Choose Executable"
        if panel.runModal() == .OK, let url = panel.url {
            pathDraft = url.path
            savePath()
        }
    }
}
