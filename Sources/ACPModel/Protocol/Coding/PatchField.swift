/// A patch field that distinguishes omission from an explicit JSON null.
public enum ACPField<Value: Equatable & Sendable>: Equatable, Sendable {
    case absent
    case null
    case value(Value)
}

extension KeyedDecodingContainer {
    func decodeACPField<Value: Decodable & Equatable & Sendable>(
        _ type: Value.Type,
        forKey key: Key
    ) throws -> ACPField<Value> {
        guard contains(key) else {
            return .absent
        }

        guard try !decodeNil(forKey: key) else {
            return .null
        }

        return (try? decode(type, forKey: key)).map(ACPField.value) ?? .absent
    }

    func decodeACPLossyArrayField<Element: Decodable & Equatable & Sendable>(
        _ type: Element.Type,
        forKey key: Key
    ) -> ACPField<[Element]> {
        guard contains(key) else {
            return .absent
        }

        guard (try? decodeNil(forKey: key)) != true else {
            return .null
        }

        guard let values = try? decode([ACPValue].self, forKey: key) else {
            return .absent
        }

        return .value(values.compactMap { try? $0.decode(Element.self) })
    }
}

extension KeyedEncodingContainer {
    mutating func encodeACPField<Value: Encodable & Equatable & Sendable>(
        _ field: ACPField<Value>,
        forKey key: Key
    ) throws {
        switch field {
        case .absent:
            break
        case .null:
            try encodeNil(forKey: key)
        case .value(let value):
            try encode(value, forKey: key)
        }
    }
}
