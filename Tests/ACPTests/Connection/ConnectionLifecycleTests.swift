import ACPTestSupport
import Foundation
import Testing

@testable import ACP
import ACPModel

extension ACPConnectionBehaviorTests {
    @Test func everyCloseWaiterReceivesTheSameTermination() async throws {
        let transport = ControlledConnectionTransport()
        let connection = ACPConnection(transport: transport)
        try await connection.start()

        async let first = connection.waitUntilClosed()
        async let second = connection.waitUntilClosed()
        await transport.finish(.endOfFile)

        #expect(await first == .endOfFile)
        #expect(await second == .endOfFile)
        #expect(await connection.waitUntilClosed() == .endOfFile)
    }
    @Test func waitUntilClosedWaitsForNotificationDrain() async throws {
        let transport = ControlledConnectionTransport()
        let callbackStarted = AsyncGate()
        let releaseCallback = AsyncGate()
        let events = ConnectionTestEvents()
        let connection = ACPConnection(
            transport: transport,
            handlers: ACPConnectionHandlers(onNotification: { _, _, _ in
                await callbackStarted.open()
                await releaseCallback.wait()
                await events.append("notification")
            })
        )
        try await connection.start()

        await transport.emit(.notification(method: "last", params: nil))
        await callbackStarted.wait()
        let waiter = Task {
            let termination = await connection.waitUntilClosed()
            await events.append(String(describing: termination))
        }
        let finish = Task { await transport.finish(.endOfFile) }
        await Task.yield()
        #expect(await events.values.isEmpty)

        await releaseCallback.open()
        await finish.value
        await waiter.value
        #expect(await events.values == ["notification", "endOfFile"])
    }
    @Test func waitUntilClosedWaitsForActiveRequestHandlers() async throws {
        let transport = ControlledConnectionTransport()
        let handlerStarted = AsyncGate()
        let handlerCancelled = AsyncGate()
        let releaseHandler = AsyncGate()
        let events = ConnectionTestEvents()
        let connection = ACPConnection(
            transport: transport,
            handlers: ACPConnectionHandlers(onRequest: { _, _, _ in
                await handlerStarted.open()
                return await withTaskCancellationHandler {
                    await releaseHandler.wait()
                    await events.append("handler")
                    return .null
                } onCancel: {
                    Task { await handlerCancelled.open() }
                }
            })
        )
        try await connection.start()

        await transport.emit(.request(id: .integer(1), method: "blocked", params: nil))
        await handlerStarted.wait()
        let closed = Task {
            let termination = await connection.waitUntilClosed()
            await events.append(String(describing: termination))
        }
        let finish = Task { await transport.finish(.endOfFile) }
        await handlerCancelled.wait()

        #expect(await events.values.isEmpty)
        await releaseHandler.open()
        await finish.value
        await closed.value
        #expect(await events.values == ["handler", "endOfFile"])
    }
    @Test func operationsBeforeStartFailImmediately() async throws {
        let transport = ControlledConnectionTransport()
        let connection = ACPConnection(transport: transport)

        await #expect(throws: ACPConnectionError.closed) {
            let _: String = try await connection.request(method: "early")
        }
        await #expect(throws: ACPConnectionError.closed) {
            try await connection.notify(method: "early", params: "value")
        }

        await connection.close()
    }
    @Test func closeIsIdempotentAndOperationsAfterCloseFailImmediately() async throws {
        let transport = ControlledConnectionTransport()
        let connection = ACPConnection(transport: transport)
        try await connection.start()

        await connection.close()
        await connection.close()
        #expect(await transport.terminationCount == 1)

        await #expect(throws: ACPConnectionError.closed) {
            let _: String = try await connection.request(method: "late")
        }
        await #expect(throws: ACPConnectionError.closed) {
            try await connection.notify(method: "late", params: "value")
        }
        #expect(await transport.waitForMessages(0).isEmpty)
    }
}
