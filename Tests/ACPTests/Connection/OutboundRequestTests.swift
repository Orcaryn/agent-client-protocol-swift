import Foundation
import Testing

@testable import ACP
import ACPModel

extension ACPConnectionBehaviorTests {
    @Test func terminationFailsEveryPendingRequestWithSameReason() async throws {
        let transport = ControlledConnectionTransport()
        let connection = ACPConnection(transport: transport)
        try await connection.start()

        let first = Task { try await connection.request(method: "one", response: String.self) }
        let second = Task { try await connection.request(method: "two", response: String.self) }
        _ = await transport.waitForMessages(2)
        await transport.finish(.processExited(9))

        for request in [first, second] {
            do {
                _ = try await request.value
                Issue.record("Expected termination")
            } catch let reason as ACPTransportTermination {
                #expect(reason == .processExited(9))
            }
        }
    }
    @Test func requestTimeoutFailsCleansUpAndSendsCancellation() async throws {
        let transport = ControlledConnectionTransport()
        let connection = ACPConnection(
            transport: transport,
            requestTimeout: .milliseconds(25)
        )
        try await connection.start()

        let request = Task {
            try await connection.request(method: "slow", response: String.self)
        }
        let first = await transport.waitForMessages(1)
        let requestID = try #require(first.requestID(for: "slow"))

        await #expect(throws: ACPConnectionError.requestTimedOut(method: "slow")) {
            _ = try await request.value
        }

        let timedOutMessages = await transport.waitForMessages(2)
        guard case .notification(let method, let params) = timedOutMessages[1] else {
            Issue.record("Expected timeout cancellation notification")
            return
        }
        #expect(method == ACPProtocol.Method.cancelRequest)
        #expect(try params?.decode(ACPCancelRequestNotification.self).requestID == requestID)

        // A late response must not complete the timed-out continuation a second time.
        await transport.emit(.response(id: requestID, result: .string("late")))

        let subsequent = Task {
            try await connection.request(method: "fast", response: String.self)
        }
        let subsequentMessages = await transport.waitForMessages(3)
        let subsequentID = try #require(subsequentMessages.requestID(for: "fast"))
        await transport.emit(.response(id: subsequentID, result: .string("ok")))
        #expect(try await subsequent.value == "ok")
        await connection.close()
    }
    @Test func zeroRequestTimeoutStillCancelsAfterTheRequestSendRace() async throws {
        let transport = ControlledConnectionTransport()
        let connection = ACPConnection(transport: transport, requestTimeout: .zero)
        try await connection.start()

        let request = Task {
            try await connection.request(method: "immediate", response: String.self)
        }
        await #expect(throws: ACPConnectionError.requestTimedOut(method: "immediate")) {
            _ = try await request.value
        }

        let messages = await transport.waitForMessages(2)
        guard case .request(let requestID, let requestMethod, _) = messages[0],
            case .notification(let cancellationMethod, let params) = messages[1]
        else {
            Issue.record("Expected request followed by cancellation")
            return
        }
        #expect(requestMethod == "immediate")
        #expect(cancellationMethod == ACPProtocol.Method.cancelRequest)
        #expect(try params?.decode(ACPCancelRequestNotification.self).requestID == requestID)
        await connection.close()
    }
}
