import ACPModel
import Foundation

struct SessionLifecycleRouter: Sendable {
    private enum SetupScope {
        case request
        case resume
    }

    let runtime: AgentRuntime
    let connection: ACPConnection

    func route(method: String, params: ACPValue) async throws -> ACPValue {
        let context = ACPAgentContext(connection: connection, runtime: runtime)
        switch method {
        case ACPProtocol.Method.sessionNew:
            return try await newSession(params, context: context)
        case ACPProtocol.Method.sessionLoad:
            return try await loadSession(params)
        case ACPProtocol.Method.sessionResume:
            return try await resumeSession(params)
        case ACPProtocol.Method.sessionList:
            return try await listSessions(params, context: context)
        case ACPProtocol.Method.sessionDelete:
            return try await deleteSession(params, context: context)
        case ACPProtocol.Method.sessionClose:
            return try await closeSession(params, context: context)
        default:
            throw ACPJSONRPCError.methodNotFound
        }
    }

    private func newSession(
        _ params: ACPValue,
        context: ACPAgentContext
    ) async throws -> ACPValue {
        let capabilities = try await runtime.capabilities.agentCapabilities()
        let request = try params.decodeParams(ACPNewSessionRequest.self)
        try SessionSetupValidator.validate(
            cwd: request.cwd,
            additionalDirectories: request.additionalDirectories,
            mcpServers: request.mcpServers,
            capabilities: capabilities
        )
        let response = try await runtime.handlers.sessions.new(context, request)
        try await validateConfigOptions(response.configOptions)
        try await runtime.sessions.register(
            sessionID: response.sessionID,
            cwd: request.cwd,
            additionalDirectories: request.additionalDirectories,
            modes: response.modes,
            configOptions: response.configOptions
        )
        return try ACPValue.encode(response)
    }

    private func loadSession(_ params: ACPValue) async throws -> ACPValue {
        let capabilities = try await runtime.capabilities.agentCapabilities()
        let handler = try requireHandler(
            runtime.handlers.sessions.load,
            enabled: capabilities.loadSession
        )
        let request = try params.decodeParams(ACPLoadSessionRequest.self)
        try SessionSetupValidator.validate(
            cwd: request.cwd,
            additionalDirectories: request.additionalDirectories,
            mcpServers: request.mcpServers,
            capabilities: capabilities
        )
        return try await withSessionSetup(
            sessionID: request.sessionID,
            cwd: request.cwd,
            additionalDirectories: request.additionalDirectories,
            scope: .request
        ) { context in
            try await handler(context, request)
        }
    }

    private func resumeSession(_ params: ACPValue) async throws -> ACPValue {
        let capabilities = try await runtime.capabilities.agentCapabilities()
        let handler = try requireHandler(
            runtime.handlers.sessions.resume,
            enabled: capabilities.sessionCapabilities.resume != nil
        )
        let request = try params.decodeParams(ACPResumeSessionRequest.self)
        try SessionSetupValidator.validate(
            cwd: request.cwd,
            additionalDirectories: request.additionalDirectories,
            mcpServers: request.mcpServers ?? [],
            capabilities: capabilities
        )
        return try await withSessionSetup(
            sessionID: request.sessionID,
            cwd: request.cwd,
            additionalDirectories: request.additionalDirectories,
            scope: .resume
        ) { context in
            try await handler(context, request)
        }
    }

    private func listSessions(
        _ params: ACPValue,
        context: ACPAgentContext
    ) async throws -> ACPValue {
        let enabled =
            try await runtime.capabilities.agentCapabilities()
            .sessionCapabilities.list != nil
        let handler = try requireHandler(runtime.handlers.sessions.list, enabled: enabled)
        let request = try params.decodeParams(ACPListSessionsRequest.self)
        if let cwd = request.cwd { try WorkspacePathPolicy.requireAbsolute(cwd) }
        let response = try await handler(context, request)
        try SessionSetupValidator.validate(listResponse: response)
        return try ACPValue.encode(response)
    }

    private func deleteSession(
        _ params: ACPValue,
        context: ACPAgentContext
    ) async throws -> ACPValue {
        let enabled =
            try await runtime.capabilities.agentCapabilities()
            .sessionCapabilities.delete != nil
        let handler = try requireHandler(runtime.handlers.sessions.delete, enabled: enabled)
        let request = try params.decodeParams(ACPSessionIDRequest.self)
        return try ACPValue.encode(try await handler(context, request))
    }

    private func closeSession(
        _ params: ACPValue,
        context: ACPAgentContext
    ) async throws -> ACPValue {
        let enabled =
            try await runtime.capabilities.agentCapabilities()
            .sessionCapabilities.close != nil
        let handler = try requireHandler(runtime.handlers.sessions.close, enabled: enabled)
        let request = try params.decodeParams(ACPSessionIDRequest.self)
        try await runtime.sessions.require(request.sessionID)
        await runtime.prompts.cancel(sessionID: request.sessionID)
        await runtime.prompts.waitUntilFinished(sessionID: request.sessionID)
        try await context.releaseSessionTerminals(sessionID: request.sessionID)
        let response = try await handler(context, request)
        await runtime.sessions.remove(request.sessionID)
        return try ACPValue.encode(response)
    }

    private func validateConfigOptions(_ options: [ACPSessionConfigOption]?) async throws {
        try ConfigurationValidator.validate(
            options,
            clientCapabilities: await runtime.capabilities.clientCapabilities()
        )
    }

    private func withSessionSetup(
        sessionID: String,
        cwd: String,
        additionalDirectories: [String]?,
        scope: SetupScope,
        operation: @Sendable (ACPAgentContext) async throws -> ACPLoadSessionResponse
    ) async throws -> ACPValue {
        let setup = try await runtime.sessions.beginSetup(
            sessionID: sessionID,
            cwd: cwd,
            additionalDirectories: additionalDirectories
        )

        let scopeID: UUID?
        let contextScope: AgentContextScope
        switch scope {
        case .request:
            let id = await runtime.contextScopes.open()
            scopeID = id
            contextScope = .request(id)
        case .resume:
            scopeID = nil
            contextScope = .resume
        }
        let context = ACPAgentContext(
            connection: connection,
            runtime: runtime,
            scope: contextScope
        )

        do {
            let response = try await operation(context)
            try await validateConfigOptions(response.configOptions)
            try await runtime.sessions.completeSetup(
                sessionID: sessionID,
                modes: response.modes,
                configOptions: response.configOptions,
                setup: setup
            )
            if let scopeID { await runtime.contextScopes.close(scopeID) }
            return try ACPValue.encode(response)
        } catch {
            if let scopeID { await runtime.contextScopes.close(scopeID) }
            await runtime.sessions.rollback(sessionID: sessionID, setup: setup)
            throw error
        }
    }

    private func requireHandler<Handler>(
        _ handler: Handler?,
        enabled: Bool = true
    ) throws -> Handler {
        guard enabled, let handler else { throw ACPJSONRPCError.methodNotFound }
        return handler
    }
}
