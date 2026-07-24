import Darwin
import Foundation
import Testing

import ACPModel

extension ACPAgentClientProcessTests {
    @Test func shutdownWaitsForAgentProcessExit() async throws {
        let pidURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: pidURL) }

        let pid = try await connectAndShutdown(recordingPIDAt: pidURL)
        #expect(processHasExited(pid))
    }
}
