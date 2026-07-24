import ACPTestSupport
import Foundation
import Testing

@testable import ACP
import ACPModel

extension ACPConnectionBehaviorTests {
    @Test func terminationDrainsInFlightSendAndItsWireEvent() async throws {
        let transport = BlockingSendTransport()
        let events = ConnectionTestEvents()
        let connection = ACPConnection(
            transport: transport,
            handlers: ACPConnectionHandlers(
                wireInspection: ACPWireInspection(onEvent: { event in
                    await events.append("wire:\(event.direction.rawValue):\(event.method ?? "response")")
                })
            )
        )
        try await connection.start()

        let send = Task {
            try await connection.notify(method: "blocked", params: ACPEmptyResponse())
        }
        await transport.waitUntilSendStarts()
        let close = Task {
            let termination = await connection.waitUntilClosed()
            await events.append("closed")
            return termination
        }

        await transport.finish(.endOfFile)
        #expect(
            !(await eventually(for: .milliseconds(50)) {
                await events.values.contains("closed")
            })
        )

        await transport.releaseBlockedSend()
        try await send.value
        #expect(await close.value == .endOfFile)
        #expect(await events.values == ["wire:outgoing:blocked", "closed"])
    }
}
