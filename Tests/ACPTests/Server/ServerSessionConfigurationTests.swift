import Testing

@testable import ACP
import ACPModel

extension ACPAgentServerTests {
    @Test func rejectsUnadvertisedSessionConfigurationBeforeHandlers() async throws {
        let routes = AgentServerRoutes()
        let transport = ScriptedAgentTransport(expectedResponseCount: 4)
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
                        await routes.record("new")
                        return ACPNewSessionResponse(
                            sessionID: "session",
                            modes: ACPSessionModeState(
                                currentModeID: "code",
                                availableModes: [ACPSessionMode(id: "code", name: "Code")]
                            ),
                            configOptions: [
                                .select(
                                    ACPSessionConfigSelect(
                                        id: "model",
                                        name: "Model",
                                        currentValue: "fast",
                                        options: .ungrouped([
                                            ACPSessionConfigSelectOption(value: "fast", name: "Fast")
                                        ])
                                    )
                                )
                            ]
                        )
                    },
                    prompt: { _, _ in ACPPromptResponse(stopReason: .endTurn) },
                    setMode: { _, _ in
                        await routes.record("unexpected-mode")
                        return ACPEmptyResponse()
                    },
                    setConfigOption: { _, _ in
                        await routes.record("unexpected-config")
                        return ACPSetConfigOptionResponse(configOptions: [])
                    }
                )
            )
        )

        let run = Task { try await server.run() }
        await transport.waitUntilStarted()
        let requests: [ACPJSONRPCMessage] = [
            try request(1, ACPProtocol.Method.initialize, ACPInitializeRequest()),
            try request(2, ACPProtocol.Method.sessionNew, ACPNewSessionRequest(cwd: "/tmp")),
            try request(
                3,
                ACPProtocol.Method.sessionSetMode,
                ACPSetSessionModeRequest(sessionID: "session", modeID: "missing")
            ),
            try request(
                4,
                ACPProtocol.Method.sessionSetConfigOption,
                ACPSetConfigOptionRequest(
                    sessionID: "session",
                    configID: "model",
                    value: .valueID("missing")
                )
            ),
        ]

        for (index, request) in requests.enumerated() {
            await transport.receive(request)
            while await transport.sentMessages().count <= index {
                await Task.yield()
            }
        }

        #expect(try await run.value == .endOfFile)
        let messages = await transport.sentMessages()
        #expect(messages.count == 4)
        for message in messages.suffix(2) {
            guard case .error(_, let error) = message else {
                Issue.record("Expected invalid-params response, got \(message)")
                continue
            }
            #expect(error.code == .invalidParams)
        }
        #expect(await routes.snapshot() == ["new"])
    }
}
