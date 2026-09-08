import SwiftUI

// MARK: - Settings View
@MainActor
struct SettingsView: View {
    let updateService: AppUpdateService
    let aiService: AIProviderService
    @State private var selection = SettingsDestination.general

    // MARK: - Body
    var body: some View {
        detail
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Settings section", selection: $selection) {
                        ForEach(SettingsDestination.allCases, id: \.self) { destination in
                            Text(destination.title)
                                .tag(destination)
                                .help(destination.title)
                        }
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.large)
                    .labelsHidden()
                    .accessibilityIdentifier("settings.section")
                }
            }
            .navigationTitle("Settings")
            .toolbarRole(.editor)
            .background(SettingsWindowConfiguration())
            .frame(width: 680, height: 640)
    }

    // MARK: - Detail
    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .general:
            GeneralSettingsView(updateService: updateService)
        case .providers:
            AIProviderSettingsView(service: aiService)
        #if DEBUG
            case .debug:
                AIDebugView(service: aiService)
        #endif
        }
    }
}

// MARK: - Settings Destination
private enum SettingsDestination: Hashable, CaseIterable {
    case general, providers
    #if DEBUG
        case debug
    #endif

    var title: String {
        switch self {
        case .general: "General"
        case .providers: "AI Providers"
        #if DEBUG
            case .debug: "AI Debug"
        #endif
        }
    }
}

#Preview {
    SettingsView(
        updateService: AppUpdateService(),
        aiService: AIProviderService(persistence: AppPersistence(inMemory: true))
    )
}
