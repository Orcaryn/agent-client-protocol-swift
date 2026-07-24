/// A wire value with a schema-defined default for missing or invalid input.
public protocol ACPWireDefault: Codable, Equatable, Sendable {
    static var acpDefault: Self { get }
}

/// Applies a schema-defined default while decoding an ACP wire value.
@propertyWrapper
public struct ACPDefault<Value: ACPWireDefault>: Codable, Equatable, Sendable {
    public var wrappedValue: Value

    public init() {
        wrappedValue = .acpDefault
    }

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        wrappedValue = (try? Value(from: decoder)) ?? .acpDefault
    }

    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

/// Defaults an optional wire value to `nil` when it is missing, null, or invalid.
@propertyWrapper
public struct ACPDefaultOnError<Value: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    public var wrappedValue: Value?

    public init(wrappedValue: Value?) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        wrappedValue = try? Value(from: decoder)
    }

    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

extension KeyedDecodingContainer {
    func decode<Value>(
        _ type: ACPDefault<Value>.Type,
        forKey key: Key
    ) -> ACPDefault<Value> {
        (try? decodeIfPresent(type, forKey: key)) ?? ACPDefault()
    }

    func decode<Value>(
        _ type: ACPDefaultOnError<Value>.Type,
        forKey key: Key
    ) -> ACPDefaultOnError<Value> {
        (try? decodeIfPresent(type, forKey: key))
            ?? ACPDefaultOnError(wrappedValue: nil)
    }
}

extension KeyedEncodingContainer {
    mutating func encode<Value>(
        _ value: ACPDefaultOnError<Value>,
        forKey key: Key
    ) throws {
        try encodeIfPresent(value.wrappedValue, forKey: key)
    }
}

extension Bool: ACPWireDefault {
    public static var acpDefault: Bool { false }
}
