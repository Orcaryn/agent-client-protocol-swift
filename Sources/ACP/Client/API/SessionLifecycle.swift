import ACPModel

extension ACPAgentClient {
    public func newSession(
        cwd: String,
        additionalDirectories: [String]? = nil,
        mcpServers: [ACPMCPServer] = [],
        _meta: ACPMeta? = nil
    ) async throws -> ACPNewSessionResponse {
        let capabilities = try initialized().agentCapabilities
        try SessionSetupValidator.validate(
            cwd: cwd,
            additionalDirectories: additionalDirectories,
            mcpServers: mcpServers,
            capabilities: capabilities
        )
        let response: ACPNewSessionResponse = try await connection.request(
            method: ACPProtocol.Method.sessionNew,
            params: ACPNewSessionRequest(
                cwd: cwd,
                additionalDirectories: additionalDirectories,
                mcpServers: mcpServers,
                _meta: _meta
            )
        )
        try validateConfigOptions(response.configOptions)
        try await runtime.sessions.register(
            sessionID: response.sessionID,
            cwd: cwd,
            additionalDirectories: additionalDirectories,
            modes: response.modes,
            configOptions: response.configOptions
        )
        return response
    }

    public func loadSession(
        sessionID: String,
        cwd: String,
        additionalDirectories: [String]? = nil,
        mcpServers: [ACPMCPServer] = [],
        _meta: ACPMeta? = nil
    ) async throws -> ACPLoadSessionResponse {
        let capabilities = try initialized().agentCapabilities
        guard capabilities.loadSession else { throw ACPJSONRPCError.methodNotFound }
        try SessionSetupValidator.validate(
            cwd: cwd,
            additionalDirectories: additionalDirectories,
            mcpServers: mcpServers,
            capabilities: capabilities
        )
        return try await withStagedSessionSetup(
            sessionID: sessionID,
            cwd: cwd,
            additionalDirectories: additionalDirectories
        ) {
            try await connection.requestAfterPrecedingNotifications(
                method: ACPProtocol.Method.sessionLoad,
                params: ACPLoadSessionRequest(
                    sessionID: sessionID,
                    cwd: cwd,
                    additionalDirectories: additionalDirectories,
                    mcpServers: mcpServers,
                    _meta: _meta
                )
            )
        }
    }

    public func resumeSession(
        sessionID: String,
        cwd: String,
        additionalDirectories: [String]? = nil,
        mcpServers: [ACPMCPServer]? = nil,
        _meta: ACPMeta? = nil
    ) async throws -> ACPResumeSessionResponse {
        let capabilities = try initialized().agentCapabilities
        guard capabilities.sessionCapabilities.resume != nil else {
            throw ACPJSONRPCError.methodNotFound
        }
        try SessionSetupValidator.validate(
            cwd: cwd,
            additionalDirectories: additionalDirectories,
            mcpServers: mcpServers ?? [],
            capabilities: capabilities
        )
        return try await withStagedSessionSetup(
            sessionID: sessionID,
            cwd: cwd,
            additionalDirectories: additionalDirectories
        ) {
            try await connection.requestAfterPrecedingNotifications(
                method: ACPProtocol.Method.sessionResume,
                params: ACPResumeSessionRequest(
                    sessionID: sessionID,
                    cwd: cwd,
                    additionalDirectories: additionalDirectories,
                    mcpServers: mcpServers,
                    _meta: _meta
                )
            )
        }
    }

    private func withStagedSessionSetup(
        sessionID: String,
        cwd: String,
        additionalDirectories: [String]?,
        operation: () async throws -> ACPLoadSessionResponse
    ) async throws -> ACPLoadSessionResponse {
        let setup = try await runtime.sessions.beginSetup(
            sessionID: sessionID,
            cwd: cwd,
            additionalDirectories: additionalDirectories
        )
        do {
            let response = try await operation()
            try validateConfigOptions(response.configOptions)
            try await runtime.sessions.completeSetup(
                sessionID: sessionID,
                modes: response.modes,
                configOptions: response.configOptions,
                setup: setup
            )
            return response
        } catch {
            await runtime.sessions.rollback(sessionID: sessionID, setup: setup)
            throw error
        }
    }

    public func listSessions(
        cwd: String? = nil,
        cursor: String? = nil,
        _meta: ACPMeta? = nil
    ) async throws -> ACPListSessionsResponse {
        guard try initialized().agentCapabilities.sessionCapabilities.list != nil else {
            throw ACPJSONRPCError.methodNotFound
        }
        if let cwd { try WorkspacePathPolicy.requireAbsolute(cwd) }
        let response: ACPListSessionsResponse = try await connection.request(
            method: ACPProtocol.Method.sessionList,
            params: ACPListSessionsRequest(cwd: cwd, cursor: cursor, _meta: _meta)
        )
        try SessionSetupValidator.validate(listResponse: response)
        return response
    }

    public func deleteSession(sessionID: String, _meta: ACPMeta? = nil) async throws {
        guard try initialized().agentCapabilities.sessionCapabilities.delete != nil else {
            throw ACPJSONRPCError.methodNotFound
        }
        let _: ACPEmptyResponse = try await connection.request(
            method: ACPProtocol.Method.sessionDelete,
            params: ACPDeleteSessionRequest(sessionID: sessionID, _meta: _meta)
        )
    }

    public func closeSession(sessionID: String, _meta: ACPMeta? = nil) async throws {
        guard try initialized().agentCapabilities.sessionCapabilities.close != nil else {
            throw ACPJSONRPCError.methodNotFound
        }
        try await runtime.sessions.require(sessionID)
        await runtime.permissions.cancel(sessionID: sessionID)
        let _: ACPEmptyResponse = try await connection.requestAfterPrecedingNotifications(
            method: ACPProtocol.Method.sessionClose,
            params: ACPCloseSessionRequest(sessionID: sessionID, _meta: _meta)
        )
        await runtime.sessions.remove(sessionID)
        await runtime.terminals.clear(sessionID: sessionID)
    }
}
