import Testing

@testable import ACP
import ACPModel

extension ACPAgentServerTests {
    @Test func extensionRoutingRequiresUnderscorePrefixAndPreservesRawParams() async throws {
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
                    new: { _, _ in ACPNewSessionResponse(sessionID: "unused") },
                    prompt: { _, _ in ACPPromptResponse(stopReason: .endTurn) }
                ),
                extensions: ACPAgentExtensionHandlers(
                    request: { _, method, params in
                        await routes.record("\(method):\(String(describing: params))")
                        return params ?? .string("absent")
                    }
                )
            )
        )

        let run = Task { try await server.run() }
        await transport.waitUntilStarted()
        await transport.receive(.request(id: .integer(1), method: "_vendor/absent", params: nil))
        await transport.receive(.request(id: .integer(2), method: "_vendor/null", params: .null))
        await transport.receive(
            .request(id: .integer(3), method: "vendor/not_extension", params: .object([:]))
        )

        #expect(try await run.value == .endOfFile)
        let messages = await transport.sentMessages()
        #expect(messages.contains(.response(id: .integer(1), result: .string("absent"))))
        #expect(messages.contains(.response(id: .integer(2), result: .null)))
        guard
            let rejected = messages.first(where: { message in
                if case .error(.integer(3), _) = message { return true }
                return false
            }), case .error(.integer(3), let error) = rejected
        else {
            Issue.record("Expected non-extension method to be rejected")
            return
        }
        #expect(error == .methodNotFound)
        #expect(await routes.snapshot().count == 2)
    }
}
