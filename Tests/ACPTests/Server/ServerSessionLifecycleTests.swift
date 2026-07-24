import Testing

@testable import ACP
import ACPModel

extension ACPAgentServerTests {
    @Test func failedSessionSetupCanRestorePreviousState() async throws {
        let sessions = SessionRegistry(role: .agent)
        try await sessions.register(sessionID: "existing", cwd: "/old", additionalDirectories: ["/shared"])

        let existingSetup = try await sessions.beginSetup(
            sessionID: "existing",
            cwd: "/replacement",
            additionalDirectories: nil
        )
        await sessions.rollback(sessionID: "existing", setup: existingSetup)
        #expect(try await sessions.effectiveRoots("existing") == ["/old", "/shared"])

        let newSetup = try await sessions.beginSetup(
            sessionID: "new",
            cwd: "/temporary",
            additionalDirectories: nil
        )
        await sessions.rollback(sessionID: "new", setup: newSetup)
        await #expect(throws: ACPJSONRPCError.resourceNotFound) {
            try await sessions.require("new")
        }

        let toolCall = ACPSessionNotification(
            sessionID: "existing",
            update: .toolCall(ACPToolCall(toolCallID: "tool", title: "Tool"))
        )
        try await sessions.apply(toolCall)
        await #expect(throws: ACPJSONRPCError.invalidParams) {
            try await sessions.apply(toolCall)
        }

        await #expect(throws: ACPJSONRPCError.invalidParams) {
            try await sessions.register(
                sessionID: "invalid-configuration",
                cwd: "/invalid",
                additionalDirectories: nil,
                modes: ACPSessionModeState(
                    currentModeID: "missing",
                    availableModes: [ACPSessionMode(id: "valid", name: "Valid")]
                )
            )
        }
        await #expect(throws: ACPJSONRPCError.resourceNotFound) {
            try await sessions.require("invalid-configuration")
        }
    }
}
