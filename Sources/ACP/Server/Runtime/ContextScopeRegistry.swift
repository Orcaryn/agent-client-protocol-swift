import ACPModel
import Foundation

enum AgentContextScope: Sendable {
    case general
    case request(UUID)
    case resume
}

actor ContextScopeRegistry {
    private var activeScopes: Set<UUID> = []

    func open() -> UUID {
        let id = UUID()
        activeScopes.insert(id)
        return id
    }

    func close(_ id: UUID) {
        activeScopes.remove(id)
    }

    func requireActive(_ scope: AgentContextScope) throws {
        switch scope {
        case .general:
            return
        case .resume:
            throw ACPJSONRPCError.invalidRequest
        case .request(let id):
            guard activeScopes.contains(id) else { throw ACPJSONRPCError.invalidRequest }
        }
    }
}
