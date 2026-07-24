import ACPModel

struct AgentInboundRouter: Sendable {
    let runtime: AgentRuntime
    var wireInspection: ACPWireInspection? = nil

    var connectionHandlers: ACPConnectionHandlers {
        ACPConnectionHandlers(onNotification: routeNotification, wireInspection: wireInspection)
    }

    var requestRouting: ACPInboundRequestRouting {
        ACPInboundRequestRouting(
            received: promptReceived,
            handle: routeRequest,
            finished: promptFinished
        )
    }

    private func promptReceived(
        id: ACPRequestID,
        method: String,
        params: ACPValue?
    ) async {
        guard method == ACPProtocol.Method.sessionPrompt,
            let params,
            let request = try? params.decode(ACPPromptRequest.self)
        else {
            return
        }
        await runtime.prompts.receive(requestID: id, sessionID: request.sessionID)
    }

    private func promptFinished(id: ACPRequestID) async {
        await runtime.prompts.abandon(requestID: id)
    }

    private func routeNotification(
        _ connection: ACPConnection,
        method: String,
        params: ACPValue?
    ) async {
        let context = ACPAgentContext(connection: connection, runtime: runtime)
        if method == ACPProtocol.Method.sessionCancel,
            let params,
            let notification = try? params.decode(ACPCancelSessionNotification.self)
        {
            await runtime.prompts.cancel(sessionID: notification.sessionID)
            await runtime.handlers.sessions.cancel?(context, notification)
        } else if method.hasPrefix("_") {
            await runtime.handlers.extensions.notification?(context, method, params)
        }
    }

    private func routeRequest(
        _ connection: ACPConnection,
        requestID: ACPRequestID,
        method: String,
        params: ACPValue?
    ) async throws -> ACPValue {
        let context = ACPAgentContext(connection: connection, runtime: runtime)
        if method.hasPrefix("_") {
            guard let handler = runtime.handlers.extensions.request else {
                throw ACPJSONRPCError.methodNotFound
            }
            return try await handler(context, method, params)
        }
        guard let params else { throw ACPJSONRPCError.invalidParams }

        switch method {
        case ACPProtocol.Method.initialize:
            let request = try params.decodeParams(ACPInitializeRequest.self)
            try await runtime.capabilities.begin(client: request.clientCapabilities)
            do {
                let value = try await runtime.handlers.lifecycle.initialize(context, request)
                let response = ACPInitializeResponse(
                    protocolVersion: ACPProtocol.version,
                    agentCapabilities: value.agentCapabilities,
                    authMethods: value.authMethods,
                    agentInfo: value.agentInfo,
                    _meta: value._meta
                )
                let encodedResponse = try ACPValue.encode(response)
                try await runtime.capabilities.complete(initialization: response)
                return encodedResponse
            } catch {
                await runtime.capabilities.failInitialization()
                throw error
            }
        case ACPProtocol.Method.authenticate:
            let request = try params.decodeParams(ACPAuthenticateRequest.self)
            try await runtime.capabilities.validateAuthMethod(request.methodID)
            guard let handler = runtime.handlers.lifecycle.authenticate else {
                throw ACPJSONRPCError.methodNotFound
            }
            return try ACPValue.encode(try await handler(context, request))
        case ACPProtocol.Method.logout:
            guard try await runtime.capabilities.agentCapabilities().auth.logout != nil else {
                throw ACPJSONRPCError.methodNotFound
            }
            guard let handler = runtime.handlers.lifecycle.logout else {
                throw ACPJSONRPCError.methodNotFound
            }
            let request = try params.decodeParams(ACPLogoutRequest.self)
            return try ACPValue.encode(try await handler(context, request))
        default:
            return try await AgentSessionRouter(
                runtime: runtime,
                connection: connection
            ).route(requestID: requestID, method: method, params: params)
        }
    }
}
