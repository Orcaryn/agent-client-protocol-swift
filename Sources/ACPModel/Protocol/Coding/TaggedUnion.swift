/// Shared coding for ACP's internally tagged union objects.
enum ACPTaggedCoding {
    static func tag(_ key: String, from decoder: Decoder) throws -> String {
        guard let tag = try ACPValue(from: decoder).objectValue?[key]?.stringValue else {
            throw ACPJSONRPCError.invalidParams
        }
        return tag
    }

    static func encode<Value: Encodable>(
        _ value: Value,
        tag: String,
        key: String,
        to encoder: Encoder
    ) throws {
        guard var object = try ACPValue.encode(value).objectValue else {
            throw ACPJSONRPCError.invalidParams
        }

        object[key] = .string(tag)
        try ACPValue.object(object).encode(to: encoder)
    }
}
