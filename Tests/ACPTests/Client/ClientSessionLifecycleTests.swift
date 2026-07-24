import ACPTestSupport
import Testing

@testable import ACP
import ACPModel

extension ACPAgentClientTests {
    @Test func resumeResponseWinsOverEarlierQueuedUpdate() async throws {
        let state = try await blockingUpdateClient(
            capabilities: ACPAgentCapabilities(
                sessionCapabilities: ACPSessionCapabilities(resume: ACPCapability())
            )
        )
        try await establishSession(
            client: state.client,
            transport: state.transport,
            configOptions: [modelConfigOption(currentValue: "fast")]
        )
        let resume = Task {
            try await state.client.resumeSession(
                sessionID: "session",
                cwd: "/workspace"
            )
        }
        try await blockNotificationQueue(
            using: state.transport,
            until: state.updateStarted
        )
        try await emitSessionUpdate(
            .configOptionUpdate(
                ACPConfigOptionUpdate(
                    configOptions: [modelConfigOption(currentValue: "fast")]
                )
            ),
            using: state.transport
        )
        try await respond(
            to: ACPProtocol.Method.sessionResume,
            after: 3,
            with: ACPResumeSessionResponse(
                configOptions: [modelConfigOption(currentValue: "smart")]
            ),
            using: state.transport
        )

        await state.releaseUpdate.open()
        _ = try await resume.value
        #expect(
            try await state.client.sessionSnapshot(sessionID: "session").configOptions
                == [modelConfigOption(currentValue: "smart")]
        )
        await state.client.shutdown()
    }
    @Test func loadSessionWaitsForReplayedSessionUpdates() async throws {
        let updateStarted = AsyncGate()
        let releaseUpdate = AsyncGate()
        let events = ClientLogs()
        let transport = ControlledConnectionTransport()
        let client = try await connectedClient(
            transport: transport,
            capabilities: ACPAgentCapabilities(loadSession: true),
            callbacks: ACPAgentClientCallbacks(
                session: ACPClientSessionCallbacks(
                    update: { _ in
                        await updateStarted.open()
                        await releaseUpdate.wait()
                        await events.record("update")
                    }
                )
            )
        )

        let load = Task {
            let response = try await client.loadSession(sessionID: "session", cwd: "/workspace")
            await events.record("load")
            return response
        }
        let loadID = try #require(
            await transport.waitForMessages(2).requestID(for: ACPProtocol.Method.sessionLoad)
        )
        await transport.emit(
            .notification(
                method: ACPProtocol.Method.sessionUpdate,
                params: try ACPValue.encode(
                    ACPSessionNotification(
                        sessionID: "session",
                        update: .userMessageChunk(
                            ACPContentChunk(content: .text(ACPTextContent(text: "history")))
                        )
                    )
                )
            )
        )
        await updateStarted.wait()
        await transport.emit(
            .response(
                id: loadID,
                result: try ACPValue.encode(ACPLoadSessionResponse())
            )
        )

        #expect(
            !(await eventually(for: .milliseconds(100)) {
                await events.messages.contains("load")
            }))

        await releaseUpdate.open()
        _ = try await load.value
        #expect(await events.messages == ["update", "load"])
        await client.shutdown()
    }
    @Test func deletingHistoryKeepsAnActiveSessionUsable() async throws {
        let transport = ControlledConnectionTransport()
        let client = try await connectedClient(
            transport: transport,
            capabilities: ACPAgentCapabilities(
                sessionCapabilities: ACPSessionCapabilities(delete: ACPCapability())
            ),
            callbacks: ACPAgentClientCallbacks()
        )

        let newSession = Task { try await client.newSession(cwd: "/workspace") }
        try await respond(
            to: ACPProtocol.Method.sessionNew,
            after: 2,
            with: ACPNewSessionResponse(sessionID: "session"),
            using: transport
        )
        _ = try await newSession.value

        let delete = Task { try await client.deleteSession(sessionID: "session") }
        try await respond(
            to: ACPProtocol.Method.sessionDelete,
            after: 3,
            with: ACPEmptyResponse(),
            using: transport
        )
        try await delete.value

        let prompt = Task {
            try await client.prompt(
                sessionID: "session",
                content: [.text(ACPTextContent(text: "still active"))]
            )
        }
        try await respond(
            to: ACPProtocol.Method.sessionPrompt,
            after: 4,
            with: ACPPromptResponse(stopReason: .endTurn),
            using: transport
        )
        #expect(try await prompt.value.stopReason == .endTurn)
        await client.shutdown()
    }
}
