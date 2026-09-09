import Foundation
import Observation
import SwiftData

// MARK: - App Persistence
@Observable @MainActor
final class AppPersistence {
    private(set) var container: ModelContainer?
    private(set) var error: String?
    private let storeURL: URL?
    private let inMemory: Bool

    // MARK: - Initialization
    init(storeURL: URL? = nil, inMemory: Bool = false) {
        self.storeURL = storeURL
        self.inMemory = inMemory
    }

    // MARK: - Store Location
    static func defaultStoreURL(
        bundleIdentifier: String = Bundle.main.bundleIdentifier ?? "com.davutcaliskan.Tastko"
    ) -> URL {
        URL.applicationSupportDirectory.appending(
            path: bundleIdentifier,
            directoryHint: .isDirectory
        )
        .appending(path: "Tastko.store")
    }

    // MARK: - Open or Retry
    func open() {
        guard container == nil else { return }
        do {
            let schema = Schema(versionedSchema: AppSchemaV1.self)
            let configuration: ModelConfiguration
            if inMemory {
                configuration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                )
            }
            else {
                let url = storeURL ?? Self.defaultStoreURL()
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                configuration = ModelConfiguration(
                    "Tastko",
                    schema: schema,
                    url: url,
                    cloudKitDatabase: .none
                )
            }
            container = try ModelContainer(
                for: schema,
                migrationPlan: AppMigrationPlan.self,
                configurations: [configuration]
            )
            error = nil
        }
        catch {
            self.error = error.localizedDescription
        }
    }
}
