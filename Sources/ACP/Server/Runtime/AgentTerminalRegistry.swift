import ACPModel

actor AgentTerminalRegistry {
    private var sessions: [String: Set<String>] = [:]

    func insert(sessionID: String, terminalID: String) {
        sessions[sessionID, default: []].insert(terminalID)
    }

    func remove(sessionID: String, terminalID: String) {
        sessions[sessionID]?.remove(terminalID)
    }

    func require(sessionID: String, terminalID: String) throws {
        guard sessions[sessionID]?.contains(terminalID) == true else {
            throw ACPJSONRPCError.resourceNotFound
        }
    }

    func all(sessionID: String) -> [String] {
        Array(sessions[sessionID] ?? [])
    }

}
