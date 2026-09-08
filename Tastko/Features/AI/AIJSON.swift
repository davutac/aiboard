import Foundation

// MARK: - Provider JSON
nonisolated enum AIJSON: Codable, Sendable, Equatable {
    case object([String: AIJSON])
    case array([AIJSON])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    // MARK: - Decode
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        }
        else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        }
        else if let value = try? container.decode(String.self) {
            self = .string(value)
        }
        else if let value = try? container.decode(Double.self) {
            self = .number(value)
        }
        else if let value = try? container.decode([String: AIJSON].self) {
            self = .object(value)
        }
        else {
            self = .array(try container.decode([AIJSON].self))
        }
    }

    // MARK: - Encode
    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    // MARK: - Values
    subscript(_ key: String) -> AIJSON { object[key] ?? .null }
    var object: [String: AIJSON] {
        if case .object(let value) = self {
            value
        }
        else {
            [:]
        }
    }
    var array: [AIJSON] {
        if case .array(let value) = self {
            value
        }
        else {
            []
        }
    }
    var string: String? {
        if case .string(let value) = self {
            value
        }
        else {
            nil
        }
    }
    var bool: Bool? {
        if case .bool(let value) = self {
            value
        }
        else {
            nil
        }
    }

    // MARK: - Data
    func data() throws -> Data { try JSONEncoder().encode(self) }
    static func decode(_ data: Data) throws -> AIJSON {
        do { return try JSONDecoder().decode(AIJSON.self, from: data) }
        catch { throw AIProviderError.invalidOutput }
    }
}
