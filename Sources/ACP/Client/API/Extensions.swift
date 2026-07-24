import ACPModel

extension ACPAgentClient {
    public func callExtension<Request: Encodable & Sendable, Response: Decodable & Sendable>(
        method: String,
        request: Request,
        response: Response.Type = Response.self
    ) async throws -> Response {
        _ = try initialized()
        try ExtensionMethodValidator.requireExtension(method)
        return try await connection.request(method: method, params: request, response: response)
    }

    public func callExtension<Request: Encodable & Sendable>(
        method: String,
        request: Request
    ) async throws {
        let _: ACPEmptyResponse = try await callExtension(method: method, request: request)
    }

    public func notifyExtension<Params: Encodable & Sendable>(
        method: String,
        params: Params
    ) async throws {
        _ = try initialized()
        try ExtensionMethodValidator.requireExtension(method)
        try await connection.notify(method: method, params: params)
    }
}
