import ACPTestSupport
import Testing

@testable import ACP
import ACPModel

extension ACPAgentClientTests {
    @Test func sessionSnapshotReflectsTrackedSessionUpdates() async throws {
        let transport = ControlledConnectionTransport()
        let client = try await connectedClient(
            transport: transport,
            capabilities: ACPAgentCapabilities(
                sessionCapabilities: ACPSessionCapabilities(
                    additionalDirectories: ACPCapability()
                )
            ),
            callbacks: ACPAgentClientCallbacks()
        )
        let initialModes = sessionModes(currentModeID: "code")
        let initialOptions = [modelConfigOption(currentValue: "fast")]

        let newSession = Task {
            try await client.newSession(
                cwd: "/workspace",
                additionalDirectories: ["/shared"]
            )
        }
        try await respond(
            to: ACPProtocol.Method.sessionNew,
            after: 2,
            with: ACPNewSessionResponse(
                sessionID: "session",
                modes: initialModes,
                configOptions: initialOptions
            ),
            using: transport
        )
        _ = try await newSession.value

        let initial = try await client.sessionSnapshot(sessionID: "session")
        #expect(initial.roots == ["/workspace", "/shared"])
        #expect(initial.modes == initialModes)
        #expect(initial.configOptions == initialOptions)
        #expect(initial.plan == nil)

        let setMode = Task { try await client.setMode(sessionID: "session", modeID: "review") }
        try await respond(
            to: ACPProtocol.Method.sessionSetMode,
            after: 3,
            with: ACPEmptyResponse(),
            using: transport
        )
        try await setMode.value
        #expect(
            try await client.sessionSnapshot(sessionID: "session").modes?.currentModeID == "review"
        )

        let updatedOptions = [modelConfigOption(currentValue: "smart")]
        let updatedPlan = ACPPlan(
            entries: [ACPPlanEntry(content: "Release", priority: .high, status: .inProgress)]
        )
        for update in [
            ACPSessionUpdate.currentModeUpdate(ACPCurrentModeUpdate(currentModeID: "code")),
            .configOptionUpdate(ACPConfigOptionUpdate(configOptions: updatedOptions)),
            .plan(updatedPlan),
        ] {
            await transport.emit(
                .notification(
                    method: ACPProtocol.Method.sessionUpdate,
                    params: try ACPValue.encode(
                        ACPSessionNotification(sessionID: "session", update: update)
                    )
                )
            )
        }

        #expect(
            await eventually {
                (try? await client.sessionSnapshot(sessionID: "session"))?.plan == updatedPlan
            }
        )
        let updated = try await client.sessionSnapshot(sessionID: "session")
        #expect(updated.roots == ["/workspace", "/shared"])
        #expect(updated.modes?.currentModeID == "code")
        #expect(updated.modes?.availableModes == initialModes.availableModes)
        #expect(updated.configOptions == updatedOptions)
        #expect(updated.plan == updatedPlan)

        await #expect(throws: ACPAgentClientError.self) {
            try await client.sessionSnapshot(sessionID: "missing")
        }
        await client.shutdown()
    }
    @Test func promptWaitsForPrecedingSessionUpdates() async throws {
        let updateStarted = AsyncGate()
        let releaseUpdate = AsyncGate()
        let events = ClientLogs()
        let transport = ControlledConnectionTransport()
        let client = try await connectedClient(
            transport: transport,
            capabilities: ACPAgentCapabilities(),
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

        let prompt = Task {
            let response = try await client.prompt(
                sessionID: "session",
                content: [.text(ACPTextContent(text: "hello"))]
            )
            await events.record("prompt")
            return response
        }
        let promptID = try #require(
            await transport.waitForMessages(3).requestID(for: ACPProtocol.Method.sessionPrompt)
        )
        await transport.emit(
            .notification(
                method: ACPProtocol.Method.sessionUpdate,
                params: try ACPValue.encode(
                    ACPSessionNotification(
                        sessionID: "session",
                        update: .agentMessageChunk(
                            ACPContentChunk(content: .text(ACPTextContent(text: "response")))
                        )
                    )
                )
            )
        )
        await updateStarted.wait()
        await transport.emit(
            .response(
                id: promptID,
                result: try ACPValue.encode(ACPPromptResponse(stopReason: .endTurn))
            )
        )

        #expect(
            !(await eventually(for: .milliseconds(100)) {
                await events.messages.contains("prompt")
            }))

        await releaseUpdate.open()
        _ = try await prompt.value
        #expect(await events.messages == ["update", "prompt"])
        await client.shutdown()
    }
    @Test func rejectedSessionUpdatesAreReportedToTheLogCallback() async throws {
        let logs = ClientLogs()
        let transport = ControlledConnectionTransport()
        let runtime = ClientRuntime(
            capabilities: ACPClientCapabilities(),
            callbacks: ACPAgentClientCallbacks(
                lifecycle: ACPClientLifecycleCallbacks(
                    log: { message in await logs.record(message) }
                )
            )
        )
        let router = ClientInboundRouter(runtime: runtime)
        let connection = ACPConnection(
            transport: transport,
            handlers: router.connectionHandlers
        )
        try await connection.start()

        await transport.emit(
            .notification(
                method: ACPProtocol.Method.sessionUpdate,
                params: .object([:])
            )
        )

        #expect(await eventually { !(await logs.messages).isEmpty })
        #expect(await logs.messages[0].hasPrefix("Ignored invalid session update:"))
        await connection.close()
    }
}
