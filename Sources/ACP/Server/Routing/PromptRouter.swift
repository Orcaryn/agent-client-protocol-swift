import ACPModel
import Foundation

struct PromptRouter: Sendable {
    let runtime: AgentRuntime
    let connection: ACPConnection

    func prompt(
        _ params: ACPValue,
        requestID: ACPRequestID
    ) async throws -> ACPValue {
        let request = try params.decodeParams(ACPPromptRequest.self)
        try await runtime.sessions.require(request.sessionID)
        try ContentCapabilityValidator.validate(
            request.prompt,
            capabilities: await runtime.capabilities.agentCapabilities().promptCapabilities
        )
        let scope = await runtime.contextScopes.open()
        let context = ACPAgentContext(
            connection: connection,
            runtime: runtime,
            scope: .request(scope)
        )

        let task: Task<ACPPromptResponse, Error>
        do {
            task = try await runtime.prompts.start(
                requestID: requestID,
                sessionID: request.sessionID,
                operation: { try await runtime.handlers.sessions.prompt(context, request) }
            )
        } catch {
            await runtime.contextScopes.close(scope)
            throw error
        }

        let result = await withTaskCancellationHandler {
            await task.result
        } onCancel: {
            task.cancel()
        }
        if Task.isCancelled {
            await runtime.prompts.cancel(sessionID: request.sessionID)
        }
        let cancelled = try await finish(
            sessionID: request.sessionID,
            scope: scope,
            context: context
        )

        switch result {
        case .success(let response):
            return try ACPValue.encode(
                cancelled ? ACPPromptResponse(stopReason: .cancelled) : response
            )
        case .failure(let error) where error is CancellationError:
            return try ACPValue.encode(ACPPromptResponse(stopReason: .cancelled))
        case .failure(let error):
            throw error
        }
    }

    private func finish(
        sessionID: String,
        scope: UUID,
        context: ACPAgentContext
    ) async throws -> Bool {
        await runtime.contextScopes.close(scope)
        do {
            try await context.releaseSessionTerminals(sessionID: sessionID)
        } catch {
            _ = await runtime.prompts.finish(sessionID: sessionID)
            throw error
        }
        return await runtime.prompts.finish(sessionID: sessionID)
    }
}
