import Foundation
import Observation

// MARK: - PanelEditorProfileStore
@Observable
@MainActor
final class PanelEditorProfileStore {
    static let shared = PanelEditorProfileStore()

    private(set) var profiles: [PanelEditorProfile] = []
    private(set) var errorDescription: String?

    @ObservationIgnored
    private let profilesDirectoryURL: URL

    var panels: [PanelEditorPanel] {
        profiles.flatMap(\.panels)
    }

    // MARK: - Initialization
    init(profilesDirectoryURL: URL = PanelEditorProfileStore.defaultProfilesDirectoryURL) {
        self.profilesDirectoryURL = profilesDirectoryURL
        reload()
    }

    // MARK: - Loading
    func reload() {
        do {
            let result = try PanelEditorProfileImporter.loadProfiles(in: profilesDirectoryURL)

            // Keep the last working keyboard when every package fails to load.
            if !result.profiles.isEmpty || result.issues.isEmpty {
                profiles = result.profiles
            }

            if !result.issues.isEmpty {
                errorDescription = result.issues.joined(separator: "\n")
            }
            else {
                errorDescription =
                    panels.isEmpty
                    ? "Create a keyboard panel in macOS Panel Editor, then reload profiles."
                    : nil
            }
        }
        catch {
            errorDescription = error.localizedDescription
        }
    }

    // MARK: - Automatic Selection
    nonisolated static func preferredPanel(
        in profiles: [PanelEditorProfile],
        forApplicationBundleIdentifier bundleIdentifier: String?,
        currentPanelIdentifier: String?
    ) -> PanelEditorPanel? {
        let orderedProfiles = profilesPrioritizingCurrentSelection(
            profiles,
            currentPanelIdentifier: currentPanelIdentifier
        )

        if let bundleIdentifier,
            let associatedPanel = orderedProfiles.lazy
                .flatMap(\.panels)
                .first(where: { panel in
                    panel.associatedApplicationBundleIdentifiers.contains { associatedIdentifier in
                        associatedIdentifier.caseInsensitiveCompare(bundleIdentifier)
                            == .orderedSame
                    }
                })
        {
            return associatedPanel
        }

        return orderedProfiles.lazy
            .flatMap(\.panels)
            .first(where: \.isDefaultHomePanel)
            ?? orderedProfiles.lazy.flatMap(\.panels).first
    }

    private nonisolated static func profilesPrioritizingCurrentSelection(
        _ profiles: [PanelEditorProfile],
        currentPanelIdentifier: String?
    ) -> [PanelEditorProfile] {
        guard
            let currentPanelIdentifier,
            let currentProfileIndex = profiles.firstIndex(where: { profile in
                profile.panels.contains { $0.id == currentPanelIdentifier }
            })
        else {
            return profiles
        }

        var orderedProfiles = profiles
        let currentProfile = orderedProfiles.remove(at: currentProfileIndex)
        orderedProfiles.insert(currentProfile, at: 0)
        return orderedProfiles
    }

    // MARK: - Location
    private nonisolated static var defaultProfilesDirectoryURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support/com.apple.AssistiveControl")
    }
}
