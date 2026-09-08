import Foundation

// MARK: - Claude Model Catalog
nonisolated enum ClaudeModelCatalog {
    struct Entry: Decodable, Sendable {
        let model: AIModelDescriptor
        let minimumVersion: String
    }

    // MARK: - Load Compatible Models
    static func models(version: String, bundle: Bundle = .main) throws -> [AIModelDescriptor] {
        guard let url = bundle.url(forResource: "ClaudeModelCatalog", withExtension: "json") else {
            throw AIProviderError.process("The bundled Claude catalog is missing.")
        }
        return try decode(Data(contentsOf: url), version: version)
    }

    // MARK: - Decode Catalog
    static func decode(_ data: Data, version: String) throws -> [AIModelDescriptor] {
        try JSONDecoder().decode([Entry].self, from: data)
            .filter { AITextOutput.version(version, atLeast: $0.minimumVersion) }.map(\.model)
    }
}
