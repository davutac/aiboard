import SwiftUI

// MARK: - AppUpdateButton
struct AppUpdateButton: View {
    @Environment(\.appUpdateService) private var updateService
    @Environment(\.floatingWindowController) private var floatingWindowController

    // MARK: - Body
    var body: some View {
        if let version = updateService.availableVersion {
            Button("Update Tastko", systemImage: "arrow.down.circle.fill") {
                updateService.checkForUpdates()
            }
            .buttonStyle(.plain)
            .labelStyle(.iconOnly)
            .foregroundStyle(.blue)
            .accessibilityLabel("Update Tastko to version \(version)")
            .help("Tastko \(version) is available. Download and install the update.")
            .disabled(!updateService.canCheckForUpdates || floatingWindowController.isScreenLocked)
        }
    }
}
