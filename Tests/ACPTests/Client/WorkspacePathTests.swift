import Testing

@testable import ACP
import ACPModel

extension ACPAgentClientTests {
    @Test func resumeStagesRootsForNestedClientRequests() async throws {
        let transport = ControlledConnectionTransport()
        let client = ACPAgentClient(
            transport: transport,
            clientCapabilities: ACPClientCapabilities(
                fs: ACPFileSystemCapabilities(readTextFile: true)
            ),
            callbacks: ACPAgentClientCallbacks(
                fileSystem: ACPClientFileSystemCallbacks(
                    readTextFile: { request in
                        #expect(request.path == "/new/file.swift")
                        return ACPReadTextFileResponse(content: "staged")
                    }
                )
            )
        )

        let connect = Task { try await client.connect() }
        let initializeMessages = await transport.waitForMessages(1)
        let initializeID = try #require(
            initializeMessages.requestID(for: ACPProtocol.Method.initialize)
        )
        await transport.emit(
            .response(
                id: initializeID,
                result: try ACPValue.encode(
                    ACPInitializeResponse(
                        protocolVersion: ACPProtocol.version,
                        agentCapabilities: ACPAgentCapabilities(
                            sessionCapabilities: ACPSessionCapabilities(
                                resume: ACPCapability()
                            )
                        )
                    )
                )
            )
        )
        _ = try await connect.value

        let resume = Task {
            try await client.resumeSession(sessionID: "session", cwd: "/new")
        }
        let resumeMessages = await transport.waitForMessages(2)
        let resumeID = try #require(
            resumeMessages.requestID(for: ACPProtocol.Method.sessionResume)
        )
        let nestedID = ACPRequestID.string("nested-read")
        await transport.emit(
            .request(
                id: nestedID,
                method: ACPProtocol.Method.fileSystemReadTextFile,
                params: try ACPValue.encode(
                    ACPReadTextFileRequest(
                        sessionID: "session",
                        path: "/new/file.swift"
                    )
                )
            )
        )

        let nestedMessages = await transport.waitForMessages(3)
        #expect(
            nestedMessages.contains(
                .response(
                    id: nestedID,
                    result: try ACPValue.encode(
                        ACPReadTextFileResponse(content: "staged")
                    )
                )
            )
        )

        await transport.emit(
            .response(
                id: resumeID,
                result: try ACPValue.encode(ACPResumeSessionResponse())
            )
        )
        _ = try await resume.value
        await client.shutdown()
    }
    @Test func sessionRegistryEnforcesRootsAndOneBasedLines() async throws {
        let registry = SessionRegistry(role: .client)
        try await registry.register(
            sessionID: "session",
            cwd: "/workspace",
            additionalDirectories: ["/shared"]
        )

        try await registry.requirePath("/workspace/file.swift", sessionID: "session")
        try await registry.requirePath("/shared/file.swift", sessionID: "session")
        await #expect(throws: ACPJSONRPCError.invalidParams) {
            try await registry.requirePath("/outside/file.swift", sessionID: "session")
        }
        #expect(throws: ACPJSONRPCError.invalidParams) {
            try SourceLocationValidator.requireOneBased(0)
        }
        try SourceLocationValidator.requireOneBased(1)

        let toolCall = ACPSessionNotification(
            sessionID: "session",
            update: .toolCall(ACPToolCall(toolCallID: "tool", title: "Tool"))
        )
        try await registry.apply(toolCall)
        await #expect(throws: ACPJSONRPCError.invalidParams) {
            try await registry.apply(toolCall)
        }
        await #expect(throws: ACPJSONRPCError.invalidParams) {
            try await registry.apply(
                ACPSessionNotification(
                    sessionID: "session",
                    update: .toolCallUpdate(ACPToolCallUpdate(toolCallID: "missing"))
                )
            )
        }

        let setup = try await registry.beginSetup(
            sessionID: "loaded",
            cwd: "/workspace",
            additionalDirectories: nil
        )
        try await registry.apply(
            ACPSessionNotification(
                sessionID: "loaded",
                update: .toolCall(ACPToolCall(toolCallID: "replayed", title: "Replay"))
            )
        )
        try await registry.completeSetup(
            sessionID: "loaded",
            modes: nil,
            configOptions: nil,
            setup: setup
        )
        try await registry.apply(
            ACPSessionNotification(
                sessionID: "loaded",
                update: .toolCallUpdate(ACPToolCallUpdate(toolCallID: "replayed"))
            )
        )
    }
}
