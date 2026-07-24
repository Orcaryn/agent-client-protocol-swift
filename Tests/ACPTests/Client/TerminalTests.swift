import Testing

@testable import ACP
import ACPModel

extension ACPAgentClientTests {
    @Test func terminalStateHandlesLimitsLargerThanInt() async throws {
        let limiter = ClientTerminalRegistry()
        let create = ACPCreateTerminalRequest(
            sessionID: "session",
            command: "test",
            outputByteLimit: UInt64.max
        )
        try await limiter.register(create, terminalID: "terminal")
        let request = ACPTerminalRequest(sessionID: "session", terminalID: "terminal")
        let response = ACPTerminalOutputResponse(output: "output", truncated: false)

        #expect(await limiter.limit(response, for: request) == response)
    }
}
