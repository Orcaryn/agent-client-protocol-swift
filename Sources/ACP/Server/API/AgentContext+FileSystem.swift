import ACPModel

extension ACPAgentContext {
    public func readTextFile(
        _ request: ACPReadTextFileRequest
    ) async throws -> ACPReadTextFileResponse {
        try await requireCapability(\.fs.readTextFile)
        try SourceLocationValidator.requireOneBased(request.line)
        try await requirePath(request.path, sessionID: request.sessionID)
        return try await connection.request(
            method: ACPProtocol.Method.fileSystemReadTextFile,
            params: request
        )
    }

    public func writeTextFile(_ request: ACPWriteTextFileRequest) async throws {
        try await requireCapability(\.fs.writeTextFile)
        try await requirePath(request.path, sessionID: request.sessionID)
        let _: ACPEmptyResponse = try await connection.request(
            method: ACPProtocol.Method.fileSystemWriteTextFile,
            params: request
        )
    }
}
