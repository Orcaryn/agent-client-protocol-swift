import Testing

@testable import ACP
import ACPModel

extension ACPConcurrencyRegressionTests {
    @Test func overlappingSessionSetupIsRejectedWithoutLosingPriorState() async throws {
        let clientSessions = SessionRegistry(role: .client)
        try await clientSessions.register(sessionID: "session", cwd: "/original", additionalDirectories: nil)
        let clientSetup = try await clientSessions.beginSetup(
            sessionID: "session",
            cwd: "/first",
            additionalDirectories: nil
        )
        await #expect(throws: ACPJSONRPCError.invalidRequest) {
            _ = try await clientSessions.beginSetup(
                sessionID: "session",
                cwd: "/second",
                additionalDirectories: nil
            )
        }
        await clientSessions.rollback(sessionID: "session", setup: clientSetup)
        try await clientSessions.requirePath("/original/file", sessionID: "session")
        await #expect(throws: ACPJSONRPCError.invalidParams) {
            try await clientSessions.requirePath("/first/file", sessionID: "session")
        }

        let agentSessions = SessionRegistry(role: .agent)
        try await agentSessions.register(sessionID: "session", cwd: "/original", additionalDirectories: nil)
        let agentSetup = try await agentSessions.beginSetup(
            sessionID: "session",
            cwd: "/first",
            additionalDirectories: nil
        )
        await #expect(throws: ACPJSONRPCError.invalidRequest) {
            _ = try await agentSessions.beginSetup(
                sessionID: "session",
                cwd: "/second",
                additionalDirectories: nil
            )
        }
        await agentSessions.rollback(sessionID: "session", setup: agentSetup)
        #expect(try await agentSessions.effectiveRoots("session") == ["/original"])
    }

    @Test func staleAgentSetupCannotMutateReplacementSession() async throws {
        let sessions = SessionRegistry(role: .agent)
        let staleSetup = try await sessions.beginSetup(
            sessionID: "session",
            cwd: "/stale",
            additionalDirectories: nil
        )
        await sessions.remove("session")
        try await sessions.register(
            sessionID: "session",
            cwd: "/replacement",
            additionalDirectories: nil,
            modes: ACPSessionModeState(
                currentModeID: "replacement",
                availableModes: [
                    ACPSessionMode(id: "replacement", name: "Replacement")
                ]
            )
        )

        await #expect(throws: ACPJSONRPCError.resourceNotFound) {
            try await sessions.completeSetup(
                sessionID: "session",
                modes: ACPSessionModeState(
                    currentModeID: "stale",
                    availableModes: [ACPSessionMode(id: "stale", name: "Stale")]
                ),
                configOptions: nil,
                setup: staleSetup
            )
        }
        try await sessions.validateMode("replacement", sessionID: "session")
        await #expect(throws: ACPJSONRPCError.invalidParams) {
            try await sessions.validateMode("stale", sessionID: "session")
        }
    }
}
