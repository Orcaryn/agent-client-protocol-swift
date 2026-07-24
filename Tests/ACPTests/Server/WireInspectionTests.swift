import Testing

@testable import ACP
import ACPModel

extension ACPAgentServerTests {
    @Test func serverForwardsWireInspectionInBothDirections() async throws {
        let transport = ScriptedAgentTransport(expectedResponseCount: 1)
        let wireEvents = ServerWireEvents()
        let server = ACPAgentServer(
            transport: transport,
            handlers: ACPAgentServerHandlers(
                lifecycle: ACPAgentLifecycleHandlers(
                    initialize: { _, request in
                        ACPInitializeResponse(protocolVersion: request.protocolVersion)
                    }
                ),
                sessions: ACPAgentSessionHandlers(
                    new: { _, _ in ACPNewSessionResponse(sessionID: "session") },
                    prompt: { _, _ in ACPPromptResponse(stopReason: .endTurn) }
                )
            ),
            wireInspection: ACPWireInspection { event in
                await wireEvents.record(event)
            }
        )

        let run = Task { try await server.run() }
        await transport.waitUntilStarted()
        await transport.receive(
            try request(1, ACPProtocol.Method.initialize, ACPInitializeRequest())
        )

        #expect(try await run.value == .endOfFile)
        #expect(
            await wireEvents.values.contains {
                $0.direction == .incoming && $0.method == ACPProtocol.Method.initialize
            }
        )
        #expect(
            await wireEvents.values.contains {
                $0.direction == .outgoing && $0.method == ACPProtocol.Method.initialize
            }
        )
    }
}
