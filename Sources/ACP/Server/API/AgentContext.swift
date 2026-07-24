import ACPModel

public struct ACPAgentContext: Sendable {
    let connection: ACPConnection
    let runtime: AgentRuntime
    let scope: AgentContextScope

    init(
        connection: ACPConnection,
        runtime: AgentRuntime,
        scope: AgentContextScope = .general
    ) {
        self.connection = connection
        self.runtime = runtime
        self.scope = scope
    }

    func requireCapability(_ keyPath: KeyPath<ACPClientCapabilities, Bool>) async throws {
        guard try await runtime.capabilities.clientCapabilities()[keyPath: keyPath] else {
            throw ACPJSONRPCError.methodNotFound
        }
    }

    func requirePath(_ path: String, sessionID: String) async throws {
        try WorkspacePathPolicy.require(
            path,
            within: await runtime.sessions.effectiveRoots(sessionID)
        )
    }
}
