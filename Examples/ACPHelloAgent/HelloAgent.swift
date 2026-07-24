import ACP
import ACPModel
import Foundation

@main
enum HelloAgent {
    static func main() async throws {
        let server = ACPAgentServer(
            handlers: ACPAgentServerHandlers(
                lifecycle: ACPAgentLifecycleHandlers(
                    initialize: { _, request in
                        ACPInitializeResponse(
                            protocolVersion: request.protocolVersion,
                            agentInfo: ACPImplementationInfo(
                                name: "acp-hello-agent",
                                title: "Hello Agent",
                                version: "1.0.0"
                            )
                        )
                    }
                ),
                sessions: ACPAgentSessionHandlers(
                    new: { _, _ in
                        ACPNewSessionResponse(sessionID: UUID().uuidString)
                    },
                    prompt: { context, request in
                        try await context.sessionUpdate(
                            ACPSessionNotification(
                                sessionID: request.sessionID,
                                update: .agentMessageChunk(
                                    ACPContentChunk(
                                        content: .text(ACPTextContent(text: "Hello from Swift ACP!"))
                                    )
                                )
                            )
                        )
                        return ACPPromptResponse(stopReason: .endTurn)
                    }
                )
            )
        )

        _ = try await server.run()
    }
}
