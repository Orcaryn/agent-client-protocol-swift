import ACPModel

struct ClientInboundRouter: Sendable {
    let runtime: ClientRuntime
    var events: @Sendable (ACPAgentClientEvent) async -> Void = { _ in }
    var wireInspection: ACPWireInspection? = nil

    var connectionHandlers: ACPConnectionHandlers {
        ACPConnectionHandlers(
            onNotification: routeNotification,
            onRequest: routeRequest,
            onLog: { message in
                await events(.log(message))
                await runtime.callbacks.lifecycle.log?(message)
            },
            onTermination: { termination in
                await events(.terminated(termination))
                await runtime.callbacks.lifecycle.termination?(termination)
            },
            wireInspection: wireInspection
        )
    }

    private func routeNotification(
        _: ACPConnection,
        method: String,
        params: ACPValue?
    ) async {
        if method == ACPProtocol.Method.sessionUpdate {
            do {
                try await routeSessionUpdate(params)
            } catch {
                await emitLog("Ignored invalid session update: \(String(describing: error))")
            }
            return
        }

        if method.hasPrefix("_") {
            await runtime.callbacks.extensions.notification?(method, params)
        }
    }

    private func routeSessionUpdate(_ params: ACPValue?) async throws {
        guard let params else { throw ACPJSONRPCError.invalidParams }
        let notification = try params.decode(ACPSessionNotification.self)
        try ToolCallValidator.validate(notification.update)
        if ConfigurationValidator.containsBoolean(notification.update),
            runtime.capabilities.session?.configOptions?.boolean == nil
        {
            throw ACPJSONRPCError.invalidRequest
        }
        try await runtime.sessions.apply(notification)
        await events(.sessionUpdate(notification))
        await runtime.callbacks.session.update?(notification)
    }

    private func emitLog(_ message: String) async {
        await events(.log(message))
        await runtime.callbacks.lifecycle.log?(message)
    }

    private func routeRequest(
        _: ACPConnection,
        method: String,
        params: ACPValue?
    ) async throws -> ACPValue {
        if method.hasPrefix("_") {
            let handler = try requireHandler(runtime.callbacks.extensions.request)
            return try await handler(method, params)
        }
        guard let params else { throw ACPJSONRPCError.invalidParams }

        switch method {
        case ACPProtocol.Method.sessionRequestPermission:
            let request = try params.decodeParams(ACPRequestPermissionRequest.self)
            try await runtime.sessions.require(request.sessionID)
            try ToolCallValidator.validate(request.toolCall)
            let handler = try requireHandler(runtime.callbacks.session.permissionRequest)
            return try ACPValue.encode(
                try await runtime.permissions.request(request, handler: handler)
            )
        case ACPProtocol.Method.fileSystemReadTextFile:
            try requireCapability(runtime.capabilities.fs.readTextFile)
            let request = try params.decodeParams(ACPReadTextFileRequest.self)
            try SourceLocationValidator.requireOneBased(request.line)
            try await runtime.sessions.requirePath(request.path, sessionID: request.sessionID)
            let handler = try requireHandler(runtime.callbacks.fileSystem.readTextFile)
            return try ACPValue.encode(try await handler(request))
        case ACPProtocol.Method.fileSystemWriteTextFile:
            try requireCapability(runtime.capabilities.fs.writeTextFile)
            let request = try params.decodeParams(ACPWriteTextFileRequest.self)
            try await runtime.sessions.requirePath(request.path, sessionID: request.sessionID)
            let handler = try requireHandler(runtime.callbacks.fileSystem.writeTextFile)
            return try ACPValue.encode(try await handler(request))
        case ACPProtocol.Method.terminalCreate:
            try requireCapability(runtime.capabilities.terminal)
            let request = try params.decodeParams(ACPCreateTerminalRequest.self)
            try await runtime.sessions.require(request.sessionID)
            if let cwd = request.cwd {
                try await runtime.sessions.requirePath(cwd, sessionID: request.sessionID)
            }
            let handler = try requireHandler(runtime.callbacks.terminal.create)
            let response = try await handler(request)
            try await runtime.terminals.register(request, terminalID: response.terminalID)
            return try ACPValue.encode(response)
        case ACPProtocol.Method.terminalOutput:
            try requireCapability(runtime.capabilities.terminal)
            let request = try params.decodeParams(ACPTerminalRequest.self)
            try await runtime.sessions.require(request.sessionID)
            try await runtime.terminals.require(request)
            let handler = try requireHandler(runtime.callbacks.terminal.output)
            let response = try await handler(request)
            return try ACPValue.encode(await runtime.terminals.limit(response, for: request))
        case ACPProtocol.Method.terminalWaitForExit:
            let handler = try requireHandler(
                runtime.callbacks.terminal.waitForExit,
                enabled: runtime.capabilities.terminal
            )
            return try await respondToTerminal(params, using: handler)
        case ACPProtocol.Method.terminalKill:
            let handler = try requireHandler(
                runtime.callbacks.terminal.kill,
                enabled: runtime.capabilities.terminal
            )
            return try await respondToTerminal(params, using: handler)
        case ACPProtocol.Method.terminalRelease:
            try requireCapability(runtime.capabilities.terminal)
            let request = try params.decodeParams(ACPTerminalRequest.self)
            try await runtime.sessions.require(request.sessionID)
            try await runtime.terminals.require(request)
            let handler = try requireHandler(runtime.callbacks.terminal.release)
            let response = try await handler(request)
            await runtime.terminals.release(request)
            return try ACPValue.encode(response)
        default:
            throw ACPJSONRPCError.methodNotFound
        }
    }

    private func respondToTerminal<Response: Encodable & Sendable>(
        _ params: ACPValue,
        using handler: @Sendable (ACPTerminalRequest) async throws -> Response
    ) async throws -> ACPValue {
        let request = try params.decodeParams(ACPTerminalRequest.self)
        try await runtime.sessions.require(request.sessionID)
        try await runtime.terminals.require(request)
        return try ACPValue.encode(try await handler(request))
    }
}

private func requireHandler<Handler>(
    _ handler: Handler?,
    enabled: Bool = true
) throws -> Handler {
    guard enabled, let handler else { throw ACPJSONRPCError.methodNotFound }
    return handler
}

private func requireCapability(_ enabled: Bool) throws {
    guard enabled else { throw ACPJSONRPCError.methodNotFound }
}
