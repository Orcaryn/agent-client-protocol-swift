import ACPModel

actor CapabilityNegotiation {
    private struct NegotiatedCapabilities {
        let clientCapabilities: ACPClientCapabilities
        let agentCapabilities: ACPAgentCapabilities
        let authMethodIDs: Set<String>
    }

    private enum State {
        case uninitialized
        case initializing(ACPClientCapabilities)
        case initialized(NegotiatedCapabilities)
    }

    private var state = State.uninitialized

    func begin(client: ACPClientCapabilities) throws {
        guard case .uninitialized = state else { throw ACPJSONRPCError.invalidRequest }
        state = .initializing(client)
    }

    func complete(initialization: ACPInitializeResponse) throws {
        guard case .initializing(let client) = state else {
            throw ACPJSONRPCError.invalidRequest
        }
        state = .initialized(
            NegotiatedCapabilities(
                clientCapabilities: client,
                agentCapabilities: initialization.agentCapabilities,
                authMethodIDs: Set(initialization.authMethods.map(\.id))
            )
        )
    }

    func failInitialization() {
        state = .uninitialized
    }

    func clientCapabilities() throws -> ACPClientCapabilities {
        try negotiatedCapabilities().clientCapabilities
    }

    func agentCapabilities() throws -> ACPAgentCapabilities {
        try negotiatedCapabilities().agentCapabilities
    }

    func validateAuthMethod(_ methodID: String) throws {
        guard try negotiatedCapabilities().authMethodIDs.contains(methodID) else {
            throw ACPJSONRPCError.invalidParams
        }
    }

    private func negotiatedCapabilities() throws -> NegotiatedCapabilities {
        guard case .initialized(let capabilities) = state else {
            throw ACPJSONRPCError.invalidRequest
        }
        return capabilities
    }
}
