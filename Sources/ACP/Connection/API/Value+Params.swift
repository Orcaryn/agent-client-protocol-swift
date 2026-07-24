import ACPModel

extension ACPValue {
    func decodeParams<T: Decodable>(_ type: T.Type) throws -> T {
        do {
            return try decode(type)
        } catch let error as ACPJSONRPCError {
            throw error
        } catch {
            throw ACPJSONRPCError.invalidParams
        }
    }
}
