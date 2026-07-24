import Foundation
import Testing

@testable import ACP
import ACPModel

extension ACPConnectionBehaviorTests {
    @Test func requestWriteFailureDoesNotLeavePendingContinuation() async throws {
        let transport = ControlledConnectionTransport()
        let connection = ACPConnection(transport: transport)
        try await connection.start()
        await transport.failNextSend(with: ConnectionTestFailure.write)

        await #expect(throws: ConnectionTestFailure.write) {
            let _: String = try await connection.request(method: "unsent")
        }

        let subsequent = Task { try await connection.request(method: "sent", response: String.self) }
        let messages = await transport.waitForMessages(1)
        guard case .request(let id, let method, _) = messages[0] else {
            Issue.record("Expected subsequent request")
            return
        }
        #expect(method == "sent")
        await transport.emit(.response(id: id, result: .string("ok")))
        #expect(try await subsequent.value == "ok")
        await connection.close()
    }
    @Test func notificationWriteFailureIsPropagated() async throws {
        let transport = ControlledConnectionTransport()
        let connection = ACPConnection(transport: transport)
        try await connection.start()
        await transport.failNextSend(with: ConnectionTestFailure.write)

        await #expect(throws: ConnectionTestFailure.write) {
            try await connection.notify(method: "event", params: "value")
        }
        await connection.close()
    }
}
