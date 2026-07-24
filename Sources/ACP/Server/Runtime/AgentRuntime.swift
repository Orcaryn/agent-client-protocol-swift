struct AgentRuntime: Sendable {
    let handlers: ACPAgentServerHandlers
    let capabilities = CapabilityNegotiation()
    let sessions = SessionRegistry(role: .agent)
    let contextScopes = ContextScopeRegistry()
    let prompts = PromptCoordinator()
    let terminals = AgentTerminalRegistry()

    init(handlers: ACPAgentServerHandlers) {
        self.handlers = handlers
    }
}
