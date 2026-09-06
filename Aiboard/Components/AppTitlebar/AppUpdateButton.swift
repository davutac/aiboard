import SwiftUI

// MARK: - AppUpdateButton
struct AppUpdateButton: View {
    @Environment(\.appUpdateService) private var updateService
    @Environment(\.floatingWindowController) private var floatingWindowController

    // MARK: - Body
    var body: some View {
        if let version = updateService.availableVersion {
            Button("Update Aiboard", systemImage: "arrow.down.circle.fill") {
                updateService.checkForUpdates()
            }
            .buttonStyle(.plain)
            .labelStyle(.iconOnly)
            .foregroundStyle(.blue)
            .accessibilityLabel("Update Aiboard to version \(version)")
            .help("Aiboard \(version) is available. Download and install the update.")
            .disabled(!updateService.canCheckForUpdates || floatingWindowController.isScreenLocked)
        }
    }
}
