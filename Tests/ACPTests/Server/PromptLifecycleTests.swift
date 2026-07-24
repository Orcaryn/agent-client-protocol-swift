import Testing

@testable import ACP
import ACPModel

extension ACPAgentServerTests {
    @Test func promptCompletionWaitsForCleanupBeforeUnblockingClose() async throws {
        let state = PromptCoordinator()
        let requestID = ACPRequestID.integer(1)
        await state.receive(requestID: requestID, sessionID: "session")
        _ = try await state.start(requestID: requestID, sessionID: "session") {
            ACPPromptResponse(stopReason: .endTurn)
        }

        let waiterFinished = AgentServerRoutes()
        let waiter = Task {
            await state.waitUntilFinished(sessionID: "session")
            await waiterFinished.record("finished")
        }
        await Task.yield()
        #expect(await waiterFinished.snapshot().isEmpty)

        _ = await state.finish(sessionID: "session")
        await waiter.value
        #expect(await waiterFinished.snapshot() == ["finished"])
    }
    @Test func selectsSupportedVersionAndCancelsPromptWithCancelledStopReason() async throws {
        let routes = AgentServerRoutes()
        let transport = ScriptedAgentTransport(expectedResponseCount: 3)
        let server = ACPAgentServer(
            transport: transport,
            handlers: ACPAgentServerHandlers(
                lifecycle: ACPAgentLifecycleHandlers(
                    initialize: { _, request in
                        ACPInitializeResponse(protocolVersion: request.protocolVersion)
                    }
                ),
                sessions: ACPAgentSessionHandlers(
                    new: { _, _ in
                        ACPNewSessionResponse(sessionID: "session-1")
                    },
                    prompt: { _, _ in
                        await routes.record("prompt-started")
                        try await Task.sleep(for: .seconds(30))
                        return ACPPromptResponse(stopReason: .endTurn)
                    },
                    cancel: { _, notification in
                        await routes.record("cancel:\(notification.sessionID)")
                    }
                )
            )
        )

        let run = Task { try await server.run() }
        await transport.waitUntilStarted()

        await transport.receive(
            try request(
                1,
                ACPProtocol.Method.initialize,
                ACPInitializeRequest(protocolVersion: 99)
            )
        )
        while await transport.sentMessages().count < 1 { await Task.yield() }
        guard
            case .response(.integer(1), let initializationValue) =
                await transport.sentMessages()[0]
        else {
            Issue.record("Expected initialize response")
            return
        }
        #expect(try initializationValue.decode(ACPInitializeResponse.self).protocolVersion == 1)

        await transport.receive(
            try request(
                2,
                ACPProtocol.Method.sessionNew,
                ACPNewSessionRequest(cwd: "/tmp")
            )
        )
        while await transport.sentMessages().count < 2 { await Task.yield() }

        await transport.receive(
            try request(
                3,
                ACPProtocol.Method.sessionPrompt,
                ACPPromptRequest(
                    sessionID: "session-1",
                    prompt: [.text(ACPTextContent(text: "hello"))]
                )
            )
        )
        while !(await routes.snapshot().contains("prompt-started")) { await Task.yield() }
        await transport.receive(
            try notification(
                method: ACPProtocol.Method.sessionCancel,
                params: ACPCancelSessionNotification(sessionID: "session-1")
            )
        )

        #expect(try await run.value == .endOfFile)
        guard
            case .response(.integer(3), let promptValue) =
                await transport.sentMessages()[2]
        else {
            Issue.record("Expected prompt response")
            return
        }
        #expect(try promptValue.decode(ACPPromptResponse.self).stopReason == .cancelled)
        #expect(await routes.snapshot().contains("cancel:session-1"))
    }
}
