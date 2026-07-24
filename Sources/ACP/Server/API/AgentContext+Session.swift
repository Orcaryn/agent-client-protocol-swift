import ACPModel

extension ACPAgentContext {
    public func sessionUpdate(_ notification: ACPSessionNotification) async throws {
        let capabilities = try await runtime.capabilities.clientCapabilities()
        try await runtime.sessions.require(notification.sessionID)
        try await runtime.contextScopes.requireActive(scope)
        try ToolCallValidator.validate(notification.update)
        if ConfigurationValidator.containsBoolean(notification.update),
            capabilities.session?.configOptions?.boolean == nil
        {
            throw ACPJSONRPCError.invalidRequest
        }
        try await runtime.sessions.apply(notification)
        try await connection.notify(method: ACPProtocol.Method.sessionUpdate, params: notification)
    }

    public func workingDirectory(sessionID: String) async throws -> String {
        try await runtime.sessions.effectiveRoots(sessionID)[0]
    }

    public func effectiveRoots(sessionID: String) async throws -> [String] {
        try await runtime.sessions.effectiveRoots(sessionID)
    }

    public func requestPermission(
        _ request: ACPRequestPermissionRequest
    ) async throws -> ACPRequestPermissionResponse {
        _ = try await runtime.capabilities.clientCapabilities()
        try await runtime.sessions.require(request.sessionID)
        try ToolCallValidator.validate(request.toolCall)
        return try await connection.request(
            method: ACPProtocol.Method.sessionRequestPermission,
            params: request
        )
    }
}
