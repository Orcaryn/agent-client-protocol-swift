import ACPTestSupport
import Darwin
import Foundation
import Testing

@testable import ACP
import ACPModel
import ACPProcess

struct ACPAgentClientProcessTests {
    @Test func processClientConvenienceForwardsWireInspection() async throws {
        let wireEvents = ProcessWireEvents()
        let client = ACPAgentClient(
            launch: makeLaunch(),
            wireInspection: ACPWireInspection { event in
                await wireEvents.record(event)
            }
        )

        _ = try await client.connect()
        await client.shutdown()

        #expect(
            await wireEvents.values.contains {
                $0.direction == .outgoing && $0.method == ACPProtocol.Method.initialize
            }
        )
        #expect(
            await wireEvents.values.contains {
                $0.direction == .incoming && $0.method == ACPProtocol.Method.initialize
            }
        )
    }
    @Test func shutdownReleasesClientCallbacksAndEventStream() async throws {
        let probe = ClientLifetimeProbe()
        let events = try await connectAndShutdown(probe: probe)

        #expect(await eventually { await probe.released })
        var remainingEvents: [ACPAgentClientEvent] = []
        for await event in events {
            remainingEvents.append(event)
        }
        #expect(remainingEvents.last == .terminated(.terminated))
    }
}
