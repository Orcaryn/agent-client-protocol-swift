import Foundation
import Testing

@testable import ACPModel

func decode<Value: Decodable>(_ type: Value.Type, _ json: String) throws -> Value {
    try JSONDecoder().decode(type, from: Data(json.utf8))
}

func expectCanonicalJSON<Value: Codable & Equatable>(
    _ value: Value,
    _ json: String
) throws {
    let decoded = try decode(Value.self, json)
    #expect(decoded == value)
    try expectEncodedJSON(value, json)
}

func expectEncodedJSON<Value: Encodable>(_ value: Value, _ json: String) throws {
    let actual = try JSONDecoder().decode(ACPValue.self, from: JSONEncoder().encode(value))
    let expected = try decode(ACPValue.self, json)
    #expect(actual == expected)
}
