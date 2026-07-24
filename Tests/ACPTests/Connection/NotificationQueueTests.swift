import Foundation
import Testing

@testable import ACP
import ACPModel

extension ACPConnectionBehaviorTests {
    @Test func notificationHandlerCanAwaitPeerRequestWithoutBlockingFrameIngestion() async throws {
        let transport = ControlledConnectionTransport()
        let events = ConnectionTestEvents()
        let connection = ACPConnection(
            transport: transport,
            handlers: ACPConnectionHandlers(onNotification: { connection, method, _ in
                let response: String = try! await connection.request(method: "nested")
                await events.append("\(method):\(response)")
            })
        )
        try await connection.start()

        let delivery = Task {
            await transport.emit(.notification(method: "outer", params: nil))
            _ = await transport.waitForMessages(1)
            await transport.emit(.response(id: .integer(1), result: .string("done")))
        }

        await delivery.value
        while await events.values.isEmpty { await Task.yield() }
        #expect(await events.values == ["outer:done"])
        await connection.close()
    }
    @Test func responseThenNotificationAreBothProcessedInOrder() async throws {
        let transport = ControlledConnectionTransport()
        let events = ConnectionTestEvents()
        let connection = ACPConnection(
            transport: transport,
            handlers: ACPConnectionHandlers(onNotification: { _, method, _ in
                await events.append(method)
            })
        )
        try await connection.start()

        let request = Task { try await connection.request(method: "work", response: String.self) }
        let sent = await transport.waitForMessages(1)
        guard case .request(let id, _, _) = sent[0] else {
            Issue.record("Expected request")
            return
        }

        await transport.emit(.response(id: id, result: .string("ok")))
        await transport.emit(.notification(method: "after", params: nil))

        #expect(try await request.value == "ok")
        while await events.values.isEmpty { await Task.yield() }
        #expect(await events.values == ["after"])
        await connection.close()
    }
}
