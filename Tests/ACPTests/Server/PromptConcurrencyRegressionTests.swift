import ACPTestSupport
import Testing

@testable import ACP
import ACPModel

extension ACPConcurrencyRegressionTests {
    @Test func requestReceiptIsRecordedBeforeLaterFrames() async throws {
        let transport = ControlledConnectionTransport()
        let events = RegressionEvents()
        let connection = ACPConnection(
            transport: transport,
            handlers: ACPConnectionHandlers(
                onNotification: { _, _, _ in
                    await events.append("notification")
                }
            ),
            requestRouting: ACPInboundRequestRouting(
                received: { _, _, _ in await events.append("request") },
                handle: { _, _, _, _ in .null },
                finished: { _ in }
            )
        )
        try await connection.start()

        await transport.emit(
            .request(id: .integer(1), method: "request", params: nil)
        )
        await transport.emit(.notification(method: "notification", params: nil))

        #expect(await eventually { await events.values.count == 2 })
        #expect(await events.values == ["request", "notification"])
        await connection.close()
    }

    @Test func promptCancellationBeforeHandlerStartupIsPreserved() async throws {
        let state = PromptCoordinator()
        let requestID = ACPRequestID.integer(1)
        await state.receive(requestID: requestID, sessionID: "session")
        await state.cancel(sessionID: "session")

        let task = try await state.start(requestID: requestID, sessionID: "session") {
            ACPPromptResponse(stopReason: .endTurn)
        }
        _ = try await task.value

        #expect(await state.finish(sessionID: "session"))
    }

    @Test func promptReceiptCountsAsInFlightForCloseWaiters() async throws {
        let state = PromptCoordinator()
        let requestID = ACPRequestID.integer(1)
        let waiterFinished = RegressionFlag()
        await state.receive(requestID: requestID, sessionID: "session")

        let waiter = Task {
            await state.waitUntilFinished(sessionID: "session")
            await waiterFinished.set()
        }
        await Task.yield()
        #expect(!(await waiterFinished.value))

        await state.cancel(sessionID: "session")
        let prompt = try await state.start(requestID: requestID, sessionID: "session") {
            try Task.checkCancellation()
            return ACPPromptResponse(stopReason: .endTurn)
        }
        _ = await prompt.result
        #expect(!(await waiterFinished.value))

        #expect(await state.finish(sessionID: "session"))
        await waiter.value
        #expect(await waiterFinished.value)
    }

    @Test func firstReceivedPromptReservesItsSession() async throws {
        let state = PromptCoordinator()
        let firstID = ACPRequestID.integer(1)
        let secondID = ACPRequestID.integer(2)
        await state.receive(requestID: firstID, sessionID: "session")
        await state.receive(requestID: secondID, sessionID: "session")

        await #expect(throws: ACPJSONRPCError.invalidRequest) {
            _ = try await state.start(requestID: secondID, sessionID: "session") {
                ACPPromptResponse(stopReason: .endTurn)
            }
        }
        let first = try await state.start(requestID: firstID, sessionID: "session") {
            ACPPromptResponse(stopReason: .endTurn)
        }
        _ = try await first.value
        #expect(!(await state.finish(sessionID: "session")))
    }

    @Test func requestCancellationPropagatesIntoAgentPrompt() async throws {
        let transport = ControlledConnectionTransport()
        let promptStarted = AsyncGate()
        let releasePrompt = RegressionFlag()
        let server = ACPAgentServer(
            transport: transport,
            handlers: ACPAgentServerHandlers(
                lifecycle: ACPAgentLifecycleHandlers(
                    initialize: { _, _ in
                        ACPInitializeResponse(protocolVersion: ACPProtocol.version)
                    }
                ),
                sessions: ACPAgentSessionHandlers(
                    new: { _, _ in ACPNewSessionResponse(sessionID: "session") },
                    prompt: { _, _ in
                        await promptStarted.open()
                        while !Task.isCancelled, !(await releasePrompt.value) {
                            await Task.yield()
                        }
                        return ACPPromptResponse(stopReason: .endTurn)
                    }
                )
            )
        )
        let run = Task { try await server.run() }
        await transport.waitUntilStarted()

        try await establishRegressionSession(using: transport)
        try await sendRegressionPrompt(using: transport)
        await promptStarted.wait()
        await transport.emit(
            .notification(
                method: ACPProtocol.Method.cancelRequest,
                params: try ACPValue.encode(
                    ACPCancelRequestNotification(requestID: .integer(3))
                )
            )
        )

        let respondedToCancellation = await eventually {
            await transport.sentMessages().count == 3
        }
        #expect(respondedToCancellation)
        await releasePrompt.set()

        let messages = await transport.waitForMessages(3)
        let response = try #require(
            messages.compactMap { message -> ACPPromptResponse? in
                guard case .response(.integer(3), let value) = message else { return nil }
                return try? value.decode(ACPPromptResponse.self)
            }.first
        )
        #expect(response.stopReason == .cancelled)

        await transport.finish(.endOfFile)
        _ = try await run.value
    }

    @Test func deletingHistoryDoesNotDisruptActivePromptCleanup() async throws {
        let transport = ControlledConnectionTransport()
        let releasePrompt = AsyncGate()
        let server = ACPAgentServer(
            transport: transport,
            handlers: ACPAgentServerHandlers(
                lifecycle: ACPAgentLifecycleHandlers(
                    initialize: { _, _ in
                        ACPInitializeResponse(
                            protocolVersion: ACPProtocol.version,
                            agentCapabilities: ACPAgentCapabilities(
                                sessionCapabilities: ACPSessionCapabilities(delete: ACPCapability())
                            )
                        )
                    }
                ),
                sessions: ACPAgentSessionHandlers(
                    new: { _, _ in ACPNewSessionResponse(sessionID: "session") },
                    prompt: { context, _ in
                        _ = try await context.createTerminal(
                            ACPCreateTerminalRequest(sessionID: "session", command: "sleep")
                        )
                        await releasePrompt.wait()
                        return ACPPromptResponse(stopReason: .endTurn)
                    },
                    delete: { _, _ in ACPEmptyResponse() }
                )
            )
        )
        let run = Task { try await server.run() }
        await transport.waitUntilStarted()

        try await establishRegressionSession(
            using: transport,
            clientCapabilities: ACPClientCapabilities(terminal: true)
        )
        try await sendRegressionPrompt(using: transport)
        try await acceptRegressionTerminal(using: transport)
        await transport.emit(
            .request(
                id: .integer(4),
                method: ACPProtocol.Method.sessionDelete,
                params: try ACPValue.encode(ACPDeleteSessionRequest(sessionID: "session"))
            )
        )
        _ = await transport.waitForMessages(4)
        await releasePrompt.open()

        let releaseID = try #require(
            await transport.waitForMessages(5).requestID(for: ACPProtocol.Method.terminalRelease)
        )
        await transport.emit(
            .response(id: releaseID, result: try ACPValue.encode(ACPEmptyResponse()))
        )
        let messages = await transport.waitForMessages(6)
        let promptResponse = try #require(
            messages.compactMap { message -> ACPPromptResponse? in
                guard case .response(.integer(3), let value) = message else { return nil }
                return try? value.decode(ACPPromptResponse.self)
            }.first
        )
        #expect(promptResponse.stopReason == .endTurn)

        await transport.finish(.endOfFile)
        _ = try await run.value
    }

    @Test func cancellationDuringPromptCleanupChangesFinalStopReason() async throws {
        let transport = ControlledConnectionTransport()
        let cancelObserved = AsyncGate()
        let server = ACPAgentServer(
            transport: transport,
            handlers: ACPAgentServerHandlers(
                lifecycle: ACPAgentLifecycleHandlers(
                    initialize: { _, _ in
                        ACPInitializeResponse(protocolVersion: ACPProtocol.version)
                    }
                ),
                sessions: ACPAgentSessionHandlers(
                    new: { _, _ in ACPNewSessionResponse(sessionID: "session") },
                    prompt: { context, _ in
                        _ = try await context.createTerminal(
                            ACPCreateTerminalRequest(sessionID: "session", command: "sleep")
                        )
                        return ACPPromptResponse(stopReason: .endTurn)
                    },
                    cancel: { _, _ in await cancelObserved.open() }
                )
            )
        )
        let run = Task { try await server.run() }
        await transport.waitUntilStarted()

        try await establishRegressionSession(
            using: transport,
            clientCapabilities: ACPClientCapabilities(terminal: true)
        )
        try await sendRegressionPrompt(using: transport)
        try await acceptRegressionTerminal(using: transport)
        let releaseID = try #require(
            await transport.waitForMessages(4).requestID(for: ACPProtocol.Method.terminalRelease)
        )
        await transport.emit(
            .notification(
                method: ACPProtocol.Method.sessionCancel,
                params: try ACPValue.encode(ACPCancelSessionNotification(sessionID: "session"))
            )
        )
        await cancelObserved.wait()
        await transport.emit(
            .response(id: releaseID, result: try ACPValue.encode(ACPEmptyResponse()))
        )

        let messages = await transport.waitForMessages(5)
        let promptResponse = try #require(
            messages.compactMap { message -> ACPPromptResponse? in
                guard case .response(.integer(3), let value) = message else { return nil }
                return try? value.decode(ACPPromptResponse.self)
            }.first
        )
        #expect(promptResponse.stopReason == .cancelled)

        await transport.finish(.endOfFile)
        _ = try await run.value
    }
}
