import ACPModel

struct ClientRuntime: Sendable {
    let capabilities: ACPClientCapabilities
    let callbacks: ACPAgentClientCallbacks
    let permissions = ACPPermissionCoordinator()
    let terminals = ClientTerminalRegistry()
    let sessions = SessionRegistry(role: .client)
    let events = ACPAgentClientEventStream()

    init(
        capabilities: ACPClientCapabilities,
        callbacks: ACPAgentClientCallbacks
    ) {
        self.capabilities = capabilities
        self.callbacks = callbacks
    }
}
