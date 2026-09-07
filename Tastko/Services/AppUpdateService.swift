import Foundation
import Observation
import Sparkle

// MARK: - AppUpdateService
@Observable
@MainActor
final class AppUpdateService: NSObject, SPUStandardUserDriverDelegate {
    static let shared = AppUpdateService()

    private(set) var canCheckForUpdates = false
    private(set) var availableVersion: String?
    private(set) var isStarted = false
    private(set) var unavailabilityReason: String?
    private var automaticChecksEnabled = false

    @ObservationIgnored private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: nil,
        userDriverDelegate: self
    )
    @ObservationIgnored private var observations: [NSKeyValueObservation] = []

    var automaticallyChecksForUpdates: Bool {
        get { automaticChecksEnabled }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    // MARK: - Startup
    func start() {
        #if DEBUG
            unavailabilityReason = "Updates are disabled in Tastko Debug."
        #else
            guard !isStarted else { return }
            guard
                let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
                let url = URL(string: feed), url.scheme == "https", url.host != nil,
                let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
                Data(base64Encoded: key)?.count == 32
            else {
                unavailabilityReason =
                    "Updates aren’t configured for this build. Set the Sparkle feed URL and public signing key."
                return
            }

            // Sparkle's updater and its KVO notifications are main-thread-only.
            observations = [
                controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) {
                    [weak self] updater, _ in
                    MainActor.assumeIsolated {
                        self?.canCheckForUpdates = updater.canCheckForUpdates
                    }
                },
                controller.updater.observe(
                    \.automaticallyChecksForUpdates,
                    options: [.initial, .new]
                ) {
                    [weak self] updater, _ in
                    MainActor.assumeIsolated {
                        self?.automaticChecksEnabled = updater.automaticallyChecksForUpdates
                    }
                },
            ]

            do {
                try controller.updater.start()
                isStarted = true
                unavailabilityReason = nil
            }
            catch {
                observations.removeAll()
                canCheckForUpdates = false
                unavailabilityReason = error.localizedDescription
            }
        #endif
    }

    // MARK: - Manual Update Check
    func checkForUpdates() {
        guard canCheckForUpdates else { return }
        controller.checkForUpdates(nil)
    }

    // MARK: - Gentle Update Reminders
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        // Announce scheduled updates in the keyboard without interrupting typing.
        false
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        availableVersion = update.displayVersionString
    }

    func standardUserDriverWillFinishUpdateSession() {
        availableVersion = nil
    }
}
