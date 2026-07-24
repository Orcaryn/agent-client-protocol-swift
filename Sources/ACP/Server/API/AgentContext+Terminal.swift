import ACPModel

extension ACPAgentContext {
    public func createTerminal(
        _ request: ACPCreateTerminalRequest
    ) async throws -> ACPCreateTerminalResponse {
        try await requireCapability(\.terminal)
        try await runtime.sessions.require(request.sessionID)
        if let cwd = request.cwd {
            try await requirePath(cwd, sessionID: request.sessionID)
        }
        let response: ACPCreateTerminalResponse = try await connection.request(
            method: ACPProtocol.Method.terminalCreate,
            params: request
        )
        await runtime.terminals.insert(
            sessionID: request.sessionID,
            terminalID: response.terminalID
        )
        return response
    }

    public func terminalOutput(
        _ request: ACPTerminalRequest
    ) async throws -> ACPTerminalOutputResponse {
        try await requireTerminal(request)
        return try await connection.request(method: ACPProtocol.Method.terminalOutput, params: request)
    }

    public func waitForTerminalExit(
        _ request: ACPTerminalRequest
    ) async throws -> ACPWaitForTerminalExitResponse {
        try await requireTerminal(request)
        return try await connection.request(
            method: ACPProtocol.Method.terminalWaitForExit,
            params: request
        )
    }

    public func killTerminal(_ request: ACPTerminalRequest) async throws {
        let _: ACPEmptyResponse = try await terminalRequest(
            request,
            method: ACPProtocol.Method.terminalKill
        )
    }

    public func releaseTerminal(_ request: ACPTerminalRequest) async throws {
        let _: ACPEmptyResponse = try await terminalRequest(
            request,
            method: ACPProtocol.Method.terminalRelease
        )
        await runtime.terminals.remove(
            sessionID: request.sessionID,
            terminalID: request.terminalID
        )
    }

    func releaseSessionTerminals(sessionID: String) async throws {
        for terminalID in await runtime.terminals.all(sessionID: sessionID) {
            try await releaseTerminal(
                ACPTerminalRequest(sessionID: sessionID, terminalID: terminalID)
            )
        }
    }

    private func terminalRequest<Response: Decodable & Sendable>(
        _ request: ACPTerminalRequest,
        method: String
    ) async throws -> Response {
        try await requireTerminal(request)
        return try await connection.request(method: method, params: request)
    }

    private func requireTerminal(_ request: ACPTerminalRequest) async throws {
        try await requireCapability(\.terminal)
        try await runtime.sessions.require(request.sessionID)
        try await runtime.terminals.require(
            sessionID: request.sessionID,
            terminalID: request.terminalID
        )
    }
}
