import Darwin
import Foundation
import Testing

@testable import ACP
import ACPModel
import ACPProcess

extension ACPAgentClientProcessTests {
    @Test func missingWriteHandlerDoesNotExposeLocalFileSystem() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let client = ACPAgentClient(
            launch: makeLaunch(environment: ["ACP_TEST_MISSING_WRITE_HANDLER_PATH": path]),
            clientCapabilities: ACPClientCapabilities(
                fs: ACPFileSystemCapabilities(writeTextFile: true)
            )
        )

        try await client.connect()
        #expect(!FileManager.default.fileExists(atPath: path))
        await client.shutdown()
    }
    @Test func cancellingPromptCancelsPendingPermissionRequest() async throws {
        let calls = ClientMethodCalls()
        let client = ACPAgentClient(
            launch: makeLaunch(environment: ["ACP_TEST_PERMISSION_DURING_PROMPT": "1"]),
            callbacks: ACPAgentClientCallbacks(
                session: ACPClientSessionCallbacks(
                    permissionRequest: { _ in
                        await calls.record("permission")
                        try await Task.sleep(for: .seconds(30))
                        return ACPRequestPermissionResponse(
                            outcome: .selected(optionID: "allow-once")
                        )
                    }
                )
            )
        )

        _ = try await client.connect()
        let session = try await client.newSession(cwd: "/tmp")
        let prompt = Task {
            try await client.prompt(
                sessionID: session.sessionID,
                content: [.text(ACPTextContent(text: "run"))]
            )
        }
        while !(await calls.methods.contains("permission")) { await Task.yield() }
        try await client.cancel(sessionID: session.sessionID)

        #expect(try await prompt.value.stopReason == .cancelled)
        await client.shutdown()
    }
    @Test func enforcesInitializationCapabilitiesPathsAndExtensionNames() async throws {
        let client = ACPAgentClient(
            launch: makeLaunch(environment: ["ACP_TEST_RESTRICTED_CAPABILITIES": "1"])
        )

        await #expect(throws: ACPAgentClientError.notInitialized) {
            try await client.newSession(cwd: "/tmp")
        }

        _ = try await client.connect()

        await #expect(throws: ACPJSONRPCError.invalidParams) {
            try await client.newSession(cwd: "relative")
        }
        await #expect(throws: ACPJSONRPCError.invalidParams) {
            try await client.newSession(cwd: "/tmp", additionalDirectories: [])
        }
        await #expect(throws: ACPJSONRPCError.invalidParams) {
            try await client.newSession(
                cwd: "/tmp",
                mcpServers: [
                    .http(ACPMCPHTTPServer(name: "remote", url: "https://example.com", headers: []))
                ]
            )
        }

        let session = try await client.newSession(cwd: "/tmp")
        await #expect(throws: ACPJSONRPCError.invalidParams) {
            try await client.prompt(
                sessionID: session.sessionID,
                content: [.image(ACPImageContent(data: "", mimeType: "image/png"))]
            )
        }
        await #expect(throws: ACPJSONRPCError.methodNotFound) {
            try await client.loadSession(sessionID: session.sessionID, cwd: "/tmp")
        }
        await #expect(throws: ACPJSONRPCError.methodNotFound) {
            try await client.resumeSession(sessionID: session.sessionID, cwd: "/tmp")
        }
        await #expect(throws: ACPJSONRPCError.methodNotFound) {
            try await client.listSessions()
        }
        await #expect(throws: ACPJSONRPCError.methodNotFound) {
            try await client.deleteSession(sessionID: session.sessionID)
        }
        await #expect(throws: ACPJSONRPCError.methodNotFound) {
            try await client.closeSession(sessionID: session.sessionID)
        }
        await #expect(throws: ACPJSONRPCError.methodNotFound) {
            try await client.logout()
        }
        await #expect(throws: ACPJSONRPCError.invalidParams) {
            try await client.authenticate(methodID: "missing")
        }
        await #expect(throws: ACPJSONRPCError.invalidParams) {
            try await client.notifyExtension(method: "vendor/not-prefixed", params: ACPEmptyResponse())
        }

        await client.shutdown()
    }
}
