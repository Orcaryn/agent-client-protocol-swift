import Foundation

public enum ACPValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case integer(Int64)
    case unsigned(UInt64)
    case double(Double)
    case string(String)
    case array([ACPValue])
    case object([String: ACPValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int64.self) {
            self = .integer(value)
        } else if let value = try? container.decode(UInt64.self) {
            self = .unsigned(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([ACPValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: ACPValue].self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .integer(let value):
            try container.encode(value)
        case .unsigned(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }

    public static func encode<T: Encodable>(_ value: T) throws -> ACPValue {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(ACPValue.self, from: data)
    }

    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let data = try JSONEncoder().encode(self)
        return try JSONDecoder().decode(type, from: data)
    }

    public var objectValue: [String: ACPValue]? {
        guard case .object(let value) = self else {
            return nil
        }

        return value
    }

    public var stringValue: String? {
        guard case .string(let value) = self else {
            return nil
        }

        return value
    }
}
