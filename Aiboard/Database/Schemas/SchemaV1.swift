import SwiftData

// MARK: - Model Aliases
typealias KeyboardModel = SchemaV1.Keyboard
typealias KeyModel = SchemaV1.Key

// MARK: - SchemaV1
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 1)
    }

    static var models: [any PersistentModel.Type] {
        [
            Keyboard.self,
            Key.self,
        ]
    }
}
