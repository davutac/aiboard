import Foundation

// MARK: - Temporary Workspace
nonisolated enum AIWorkspace {
    // MARK: - Create
    static func create() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(
            path: "Tastko-AI-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        return url
    }
}
