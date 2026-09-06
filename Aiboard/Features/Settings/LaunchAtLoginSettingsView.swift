import AppKit
import OSLog
import ServiceManagement
import SwiftUI

// MARK: - LaunchAtLoginSettingsView
struct LaunchAtLoginSettingsView: View {
    @State private var status = SMAppService.mainApp.status
    @State private var isUpdating = false
    @State private var errorMessage: String?
    @State private var preloginInstalled = false

    // MARK: - Body
    var body: some View {
        Section("Startup") {
            Toggle(
                "Open Aiboard at login",
                isOn: Binding(
                    get: { status == .enabled || status == .requiresApproval },
                    set: setEnabled
                )
            )
            .disabled(isUpdating)
            .accessibilityIdentifier("launch-at-login")

            Text(statusMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("launch-at-login-status")

            if preloginInstalled {
                Text(
                    "Aiboard is also installed for the Mac login window. Reinstall to refresh its copy of your home keyboard."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("prelogin-installation-status")
            }

            if status == .requiresApproval {
                Button("Open Login Items Settings") {
                    SMAppService.openSystemSettingsLoginItems()
                }
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
        .onAppear(perform: refreshStatus)
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        ) { _ in
            refreshStatus()
        }
    }

    // MARK: - Registration
    private func setEnabled(_ enabled: Bool) {
        guard !isUpdating else { return }
        isUpdating = true
        errorMessage = nil
        Task { @MainActor in
            defer {
                refreshStatus()
                isUpdating = false
            }
            do {
                let service = SMAppService.mainApp
                if enabled {
                    if service.status == .notRegistered || service.status == .notFound {
                        try service.register()
                    }
                }
                else if service.status != .notRegistered {
                    try await service.unregister()
                }
            }
            catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func refreshStatus() {
        status = SMAppService.mainApp.status
        preloginInstalled = FileManager.default.fileExists(
            atPath: "/Library/LaunchAgents/com.davutcaliskan.Aiboard.LoginWindow.plist"
        )
        Logger(subsystem: "com.davutcaliskan.Aiboard", category: "LaunchAtLogin")
            .notice("Login registration status: \(self.status.rawValue)")
    }

    // MARK: - Status
    private var statusMessage: String {
        switch status {
        case .enabled: "Enabled. Aiboard opens after you sign in to your Mac."
        case .requiresApproval: "Allow Aiboard in macOS Login Items to finish enabling startup."
        case .notRegistered:
            "Start Aiboard automatically after signing in, including after a restart."
        case .notFound: "macOS could not find this app's login item. Try enabling it again."
        @unknown default: "Login-item status is unavailable."
        }
    }
}
