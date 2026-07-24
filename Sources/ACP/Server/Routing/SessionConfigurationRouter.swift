import ACPModel

struct SessionConfigurationRouter: Sendable {
    let runtime: AgentRuntime
    let connection: ACPConnection

    func route(method: String, params: ACPValue) async throws -> ACPValue {
        let context = ACPAgentContext(connection: connection, runtime: runtime)
        switch method {
        case ACPProtocol.Method.sessionSetMode:
            let request = try params.decodeParams(ACPSetSessionModeRequest.self)
            try await runtime.sessions.validateMode(request.modeID, sessionID: request.sessionID)
            guard let handler = runtime.handlers.sessions.setMode else {
                throw ACPJSONRPCError.methodNotFound
            }
            return try ACPValue.encode(try await handler(context, request))
        case ACPProtocol.Method.sessionSetConfigOption:
            return try await setConfigOption(params, context: context)
        default:
            throw ACPJSONRPCError.methodNotFound
        }
    }

    private func setConfigOption(
        _ params: ACPValue,
        context: ACPAgentContext
    ) async throws -> ACPValue {
        guard let handler = runtime.handlers.sessions.setConfigOption else {
            throw ACPJSONRPCError.methodNotFound
        }
        let request = try params.decodeParams(ACPSetConfigOptionRequest.self)
        try await runtime.sessions.validateConfig(
            request.configID,
            value: request.value,
            sessionID: request.sessionID
        )
        let response = try await handler(context, request)
        try ConfigurationValidator.validate(
            response.configOptions,
            clientCapabilities: await runtime.capabilities.clientCapabilities()
        )
        try await runtime.sessions.replaceConfigOptions(
            response.configOptions,
            sessionID: request.sessionID
        )
        return try ACPValue.encode(response)
    }
}
