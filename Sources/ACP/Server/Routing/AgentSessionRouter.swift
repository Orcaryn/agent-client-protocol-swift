import ACPModel

struct AgentSessionRouter: Sendable {
    let runtime: AgentRuntime
    let connection: ACPConnection

    func route(
        requestID: ACPRequestID,
        method: String,
        params: ACPValue
    ) async throws -> ACPValue {
        switch method {
        case ACPProtocol.Method.sessionNew,
            ACPProtocol.Method.sessionLoad,
            ACPProtocol.Method.sessionResume,
            ACPProtocol.Method.sessionList,
            ACPProtocol.Method.sessionDelete,
            ACPProtocol.Method.sessionClose:
            return try await SessionLifecycleRouter(
                runtime: runtime,
                connection: connection
            ).route(method: method, params: params)
        case ACPProtocol.Method.sessionPrompt:
            return try await PromptRouter(runtime: runtime, connection: connection)
                .prompt(params, requestID: requestID)
        case ACPProtocol.Method.sessionSetMode,
            ACPProtocol.Method.sessionSetConfigOption:
            return try await SessionConfigurationRouter(runtime: runtime, connection: connection)
                .route(method: method, params: params)
        default:
            throw ACPJSONRPCError.methodNotFound
        }
    }
}
