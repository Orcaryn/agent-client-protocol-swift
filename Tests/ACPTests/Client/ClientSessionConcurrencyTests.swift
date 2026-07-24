import ACPTestSupport
import Testing

@testable import ACP
import ACPModel

extension ACPConcurrencyRegressionTests {
    @Test func closeSessionWaitsForQueuedSessionUpdates() async throws {
        let transport = ControlledConnectionTransport()
        let firstUpdateStarted = AsyncGate()
        let releaseFirstUpdate = AsyncGate()
        let updateCount = RegressionCounter()
        let logCount = RegressionCounter()
        let client = ACPAgentClient(
            transport: transport,
            callbacks: ACPAgentClientCallbacks(
                session: ACPClientSessionCallbacks(
                    update: { _ in
                        if await updateCount.increment() == 1 {
                            await firstUpdateStarted.open()
                            await releaseFirstUpdate.wait()
                        }
                    }
                ),
                lifecycle: ACPClientLifecycleCallbacks(
                    log: { _ in await logCount.increment() }
                )
            )
        )
        try await connectRegressionClient(
            client,
            transport: transport,
            capabilities: ACPAgentCapabilities(
                sessionCapabilities: ACPSessionCapabilities(close: ACPCapability())
            )
        )

        let newSession = Task { try await client.newSession(cwd: "/workspace") }
        let newSessionID = try #require(
            await transport.waitForMessages(2).requestID(for: ACPProtocol.Method.sessionNew)
        )
        await transport.emit(
            .response(
                id: newSessionID,
                result: try ACPValue.encode(ACPNewSessionResponse(sessionID: "session"))
            )
        )
        _ = try await newSession.value

        let update = { (text: String) in
            ACPSessionNotification(
                sessionID: "session",
                update: .agentMessageChunk(
                    ACPContentChunk(content: .text(ACPTextContent(text: text)))
                )
            )
        }
        await transport.emit(
            .notification(
                method: ACPProtocol.Method.sessionUpdate,
                params: try ACPValue.encode(update("first"))
            )
        )
        await firstUpdateStarted.wait()
        await transport.emit(
            .notification(
                method: ACPProtocol.Method.sessionUpdate,
                params: try ACPValue.encode(update("second"))
            )
        )

        let close = Task { try await client.closeSession(sessionID: "session") }
        let closeID = try #require(
            await transport.waitForMessages(3).requestID(for: ACPProtocol.Method.sessionClose)
        )
        await transport.emit(
            .response(id: closeID, result: try ACPValue.encode(ACPEmptyResponse()))
        )
        #expect(!(await eventually(for: .milliseconds(100)) { await updateCount.value == 2 }))

        await releaseFirstUpdate.open()
        try await close.value

        #expect(await updateCount.value == 2)
        #expect(await logCount.value == 0)
        await client.shutdown()
    }
}
