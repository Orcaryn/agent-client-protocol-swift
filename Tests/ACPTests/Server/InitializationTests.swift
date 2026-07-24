import Testing

@testable import ACP
import ACPModel

struct ACPAgentServerTests {
    @Test func initializationStateIsAtomicOneShotAndRetryableAfterFailure() async throws {
        let state = CapabilityNegotiation()
        let firstClient = ACPClientCapabilities(terminal: true)
        let firstAgent = ACPAgentCapabilities(loadSession: true)

        try await state.begin(client: firstClient)
        await #expect(throws: ACPJSONRPCError.invalidRequest) {
            try await state.begin(client: ACPClientCapabilities())
        }
        await #expect(throws: ACPJSONRPCError.invalidRequest) {
            _ = try await state.clientCapabilities()
        }
        try await state.complete(
            initialization: ACPInitializeResponse(
                protocolVersion: ACPProtocol.version,
                agentCapabilities: firstAgent,
                authMethods: [ACPAuthMethod(id: "token", name: "Token")]
            )
        )
        #expect(try await state.clientCapabilities() == firstClient)
        #expect(try await state.agentCapabilities() == firstAgent)
        try await state.validateAuthMethod("token")
        await #expect(throws: ACPJSONRPCError.invalidParams) {
            try await state.validateAuthMethod("unknown")
        }
        await #expect(throws: ACPJSONRPCError.invalidRequest) {
            try await state.begin(client: ACPClientCapabilities())
        }

        let retryable = CapabilityNegotiation()
        try await retryable.begin(client: ACPClientCapabilities())
        await retryable.failInitialization()
        try await retryable.begin(client: firstClient)
        try await retryable.complete(
            initialization: ACPInitializeResponse(
                protocolVersion: ACPProtocol.version,
                agentCapabilities: firstAgent
            )
        )
        #expect(try await retryable.clientCapabilities() == firstClient)
    }
}
