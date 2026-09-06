import SwiftUI

// MARK: - AppUpdateSettingsView
struct AppUpdateSettingsView: View {
    @Bindable var updateService: AppUpdateService

    // MARK: - Body
    var body: some View {
        Section("Updates") {
            Toggle(
                "Automatically check for updates",
                isOn: $updateService.automaticallyChecksForUpdates
            )
            .disabled(!updateService.isStarted)
            Button("Check for Updates…", action: updateService.checkForUpdates)
                .disabled(!updateService.canCheckForUpdates)
            if let reason = updateService.unavailabilityReason {
                Text(reason)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
