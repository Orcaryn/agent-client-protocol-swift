import ACPTestSupport
import Foundation
import Testing

@testable import ACP
import ACPModel

extension ACPConnectionBehaviorTests {
    @Test func requestHandlerCanAwaitPeerRequestWithoutDeadlock() async throws {
        let transport = ControlledConnectionTransport()
        let connection = ACPConnection(
            transport: transport,
            handlers: ACPConnectionHandlers(onRequest: { connection, method, _ in
                let nested: String = try await connection.request(method: "nested")
                return .string("\(method):\(nested)")
            })
        )
        try await connection.start()

        await transport.emit(.request(id: .integer(10), method: "outer", params: nil))
        let first = await transport.waitForMessages(1)
        guard case .request(let nestedID, let method, _) = first[0] else {
            Issue.record("Expected nested request")
            return
        }
        #expect(method == "nested")

        await transport.emit(.response(id: nestedID, result: .string("done")))
        let sent = await transport.waitForMessages(2)
        #expect(sent[1] == .response(id: .integer(10), result: .string("outer:done")))
        await connection.close()
    }
    @Test func concurrentInboundRequestsMayCompleteOutOfOrder() async throws {
        let firstGate = AsyncGate()
        let secondGate = AsyncGate()
        let transport = ControlledConnectionTransport()
        let connection = ACPConnection(
            transport: transport,
            handlers: ACPConnectionHandlers(onRequest: { _, method, _ in
                if method == "first" { await firstGate.wait() }
                if method == "second" { await secondGate.wait() }
                return .string(method)
            })
        )
        try await connection.start()

        await transport.emit(.request(id: .integer(1), method: "first", params: nil))
        await transport.emit(.request(id: .integer(2), method: "second", params: nil))
        await secondGate.open()
        let firstResponse = await transport.waitForMessages(1)
        #expect(firstResponse[0] == .response(id: .integer(2), result: .string("second")))

        await firstGate.open()
        let responses = await transport.waitForMessages(2)
        #expect(responses[1] == .response(id: .integer(1), result: .string("first")))
        await connection.close()
    }
}
