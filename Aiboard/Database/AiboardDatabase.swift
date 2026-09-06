import Foundation
import SwiftData

// MARK: - AiboardDatabase
enum AiboardDatabase {
    static let modelContainer: ModelContainer = makeModelContainer()

    // MARK: - Model Container
    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, url: storeURL)

        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: MigrationPlan.self,
                configurations: [configuration]
            )
        }
        catch {
            #if DEBUG
            resetLocalStore()

            do {
                return try ModelContainer(
                    for: schema,
                    migrationPlan: MigrationPlan.self,
                    configurations: [configuration]
                )
            }
            catch {
                fatalError("Failed to initialize Aiboard database: \(error)")
            }
            #else
            fatalError("Failed to initialize Aiboard database: \(error)")
            #endif
        }
    }

    private static var storeURL: URL {
        let applicationSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let directoryURL = applicationSupportURL.appending(
            path: Bundle.main.bundleIdentifier ?? "Aiboard",
            directoryHint: .isDirectory
        )

        try? FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        return directoryURL.appending(path: "Aiboard.store")
    }

    private static func resetLocalStore() {
        let storePath = storeURL.path

        for path in [storePath, "\(storePath)-wal", "\(storePath)-shm"] {
            try? FileManager.default.removeItem(atPath: path)
        }
    }
}
