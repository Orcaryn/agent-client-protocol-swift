import ACPModel

enum ExtensionMethodValidator {
    static func requireExtension(_ method: String) throws {
        guard method.hasPrefix("_") else { throw ACPJSONRPCError.invalidParams }
    }
}
