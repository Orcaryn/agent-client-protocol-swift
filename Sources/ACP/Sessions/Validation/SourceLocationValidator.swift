import ACPModel

enum SourceLocationValidator {
    static func requireOneBased(_ line: UInt32?) throws {
        if line == 0 { throw ACPJSONRPCError.invalidParams }
    }
}
