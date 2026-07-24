extension Sequence where Element == ACPValue {
    fileprivate func decodeLossy<Value: Decodable>(_ type: Value.Type) -> [Value] {
        compactMap { try? $0.decode(type) }
    }
}

/// An optional array that drops individual elements which do not match the ACP schema.
@propertyWrapper
public struct ACPLossyOptionalArray<Element: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    public var wrappedValue: [Element]?

    public init(wrappedValue: [Element]?) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        wrappedValue =
            container.decodeNil()
            ? nil
            : (try? container.decode([ACPValue].self))?.decodeLossy(Element.self) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

extension KeyedDecodingContainer {
    func decode<Element>(
        _ type: ACPLossyOptionalArray<Element>.Type,
        forKey key: Key
    ) -> ACPLossyOptionalArray<Element> {
        ACPLossyOptionalArray(
            wrappedValue: (try? decodeIfPresent([ACPValue].self, forKey: key))?
                .decodeLossy(Element.self)
        )
    }
}

extension KeyedEncodingContainer {
    mutating func encode<Element>(
        _ value: ACPLossyOptionalArray<Element>,
        forKey key: Key
    ) throws {
        try encodeIfPresent(value.wrappedValue, forKey: key)
    }
}

/// A required array that drops individual elements which do not match the ACP schema.
@propertyWrapper
public struct ACPRequiredLossyArray<Element: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    public var wrappedValue: [Element]

    public init(wrappedValue: [Element]) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        wrappedValue = (try? [ACPValue](from: decoder))?.decodeLossy(Element.self) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

extension KeyedDecodingContainer {
    func decode<Element>(
        _ type: ACPRequiredLossyArray<Element>.Type,
        forKey key: Key
    ) throws -> ACPRequiredLossyArray<Element> {
        guard contains(key) else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Missing required array"
                )
            )
        }

        return ACPRequiredLossyArray(
            wrappedValue: (try? decode([ACPValue].self, forKey: key))?
                .decodeLossy(Element.self) ?? []
        )
    }
}

extension KeyedEncodingContainer {
    mutating func encode<Element>(
        _ value: ACPRequiredLossyArray<Element>,
        forKey key: Key
    ) throws {
        try encode(value.wrappedValue, forKey: key)
    }
}

/// An array that defaults to empty and drops elements which do not match the ACP schema.
@propertyWrapper
public struct ACPDefaultLossyArray<Element: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    public var wrappedValue: [Element]

    public init() {
        wrappedValue = []
    }

    public init(wrappedValue: [Element]) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        wrappedValue = (try? [ACPValue](from: decoder))?.decodeLossy(Element.self) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

extension KeyedDecodingContainer {
    func decode<Element>(
        _ type: ACPDefaultLossyArray<Element>.Type,
        forKey key: Key
    ) -> ACPDefaultLossyArray<Element> {
        (try? decodeIfPresent(type, forKey: key)) ?? ACPDefaultLossyArray()
    }
}
