import ACPModel

extension ACPAgentClient {
    public func prompt(
        sessionID: String,
        content: [ACPContentBlock],
        _meta: ACPMeta? = nil
    ) async throws -> ACPPromptResponse {
        let capabilities = try initialized().agentCapabilities.promptCapabilities
        try await runtime.sessions.require(sessionID)
        try ContentCapabilityValidator.validate(content, capabilities: capabilities)
        await runtime.permissions.beginPrompt(sessionID: sessionID)
        return try await connection.requestAfterPrecedingNotifications(
            method: ACPProtocol.Method.sessionPrompt,
            params: ACPPromptRequest(sessionID: sessionID, prompt: content, _meta: _meta)
        )
    }

    public func cancel(sessionID: String, _meta: ACPMeta? = nil) async throws {
        _ = try initialized()
        try await runtime.sessions.require(sessionID)
        await runtime.permissions.cancel(sessionID: sessionID)
        try await connection.notify(
            method: ACPProtocol.Method.sessionCancel,
            params: ACPCancelSessionNotification(sessionID: sessionID, _meta: _meta)
        )
    }

    public func setConfigOption(
        sessionID: String,
        configID: String,
        value: ACPSessionConfigValue,
        _meta: ACPMeta? = nil
    ) async throws -> [ACPSessionConfigOption] {
        _ = try initialized()
        try await runtime.sessions.validateConfig(configID, value: value, sessionID: sessionID)
        let request = ACPSetConfigOptionRequest(
            sessionID: sessionID,
            configID: configID,
            value: value,
            _meta: _meta
        )
        let response: ACPSetConfigOptionResponse =
            try await connection
            .requestAfterPrecedingNotifications(
                method: ACPProtocol.Method.sessionSetConfigOption,
                params: request
            )
        try validateConfigOptions(response.configOptions)
        try await runtime.sessions.replaceConfigOptions(response.configOptions, sessionID: sessionID)
        return response.configOptions
    }

    public func setMode(sessionID: String, modeID: String, _meta: ACPMeta? = nil) async throws {
        _ = try initialized()
        try await runtime.sessions.validateMode(modeID, sessionID: sessionID)
        let _: ACPEmptyResponse = try await connection.requestAfterPrecedingNotifications(
            method: ACPProtocol.Method.sessionSetMode,
            params: ACPSetSessionModeRequest(sessionID: sessionID, modeID: modeID, _meta: _meta)
        )
        try await runtime.sessions.setCurrentMode(modeID, sessionID: sessionID)
    }

    public func currentPlan(sessionID: String) async -> ACPPlan? {
        await runtime.sessions.plan(sessionID: sessionID)
    }

    /// Returns an immutable snapshot of the state currently tracked for a session.
    public func sessionSnapshot(sessionID: String) async throws -> ACPSessionSnapshot {
        let state = try await runtime.sessions.snapshot(sessionID)
        return ACPSessionSnapshot(
            roots: state.roots,
            modes: state.modes,
            configOptions: state.configOptions,
            plan: state.plan
        )
    }
}
