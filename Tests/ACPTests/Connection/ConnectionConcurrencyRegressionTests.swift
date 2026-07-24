import ACPTestSupport
import Testing

@testable import ACP
import ACPModel

extension ACPConcurrencyRegressionTests {
    @Test func notificationCallbackCanAwaitBarrierRequest() async throws {
        let transport = ControlledConnectionTransport()
        let completed = RegressionFlag()
        let connection = ACPConnection(
            transport: transport,
            handlers: ACPConnectionHandlers(onNotification: { connection, _, _ in
                do {
                    let _: ACPEmptyResponse =
                        try await connection.requestAfterPrecedingNotifications(
                            method: "nested",
                            params: ACPEmptyResponse()
                        )
                    await completed.set()
                } catch {}
            })
        )
        try await connection.start()

        await transport.emit(.notification(method: "trigger", params: nil))
        let id = try #require(
            await transport.waitForMessages(1).requestID(for: "nested")
        )
        await transport.emit(
            .response(id: id, result: try ACPValue.encode(ACPEmptyResponse()))
        )

        #expect(await eventually { await completed.value })
        await connection.close()
    }

    @Test func notificationCallbackCanCloseItsConnection() async throws {
        let transport = ControlledConnectionTransport()
        let completed = RegressionFlag()
        let connection = ACPConnection(
            transport: transport,
            handlers: ACPConnectionHandlers(onNotification: { connection, _, _ in
                await connection.beginClose()
                await completed.set()
            })
        )
        try await connection.start()

        await transport.emit(.notification(method: "trigger", params: nil))

        #expect(await eventually { await completed.value })
        #expect(await connection.waitUntilClosed() == .terminated)
        await connection.close()
    }

    @Test func childOfCompletedNotificationCallbackStillWaitsForCloseDrain() async throws {
        let transport = EarlyReturningTerminationTransport()
        let childMayClose = AsyncGate()
        let childClosing = AsyncGate()
        let childClosed = RegressionFlag()
        let childSpawned = AsyncGate()
        let blockerStarted = AsyncGate()
        let releaseBlocker = AsyncGate()
        let connection = ACPConnection(
            transport: transport,
            handlers: ACPConnectionHandlers(onNotification: { connection, method, _ in
                if method == "spawn-child" {
                    Task {
                        await childMayClose.wait()
                        await childClosing.open()
                        await connection.close()
                        await childClosed.set()
                    }
                    await childSpawned.open()
                } else if method == "block-drain" {
                    await blockerStarted.open()
                    await releaseBlocker.wait()
                }
            })
        )
        try await connection.start()

        await transport.emit(.notification(method: "spawn-child", params: nil))
        await childSpawned.wait()
        await transport.emit(.notification(method: "block-drain", params: nil))
        await blockerStarted.wait()

        await childMayClose.open()
        await childClosing.wait()
        #expect(!(await eventually(for: .milliseconds(100)) { await childClosed.value }))

        await releaseBlocker.open()
        #expect(await eventually { await childClosed.value })
        #expect(await connection.waitUntilClosed() == .terminated)
    }

    @Test func closeWaitsForAsynchronousTerminationCallback() async throws {
        let transport = EarlyReturningTerminationTransport()
        let callbackStarted = AsyncGate()
        let releaseCallback = AsyncGate()
        let closeReturned = RegressionFlag()
        let connection = ACPConnection(
            transport: transport,
            handlers: ACPConnectionHandlers(onTermination: { _ in
                await callbackStarted.open()
                await releaseCallback.wait()
            })
        )
        try await connection.start()

        let close = Task {
            await connection.close()
            await closeReturned.set()
        }
        await callbackStarted.wait()
        #expect(!(await eventually(for: .milliseconds(100)) { await closeReturned.value }))

        await releaseCallback.open()
        await close.value
        #expect(await closeReturned.value)
    }

    @Test func closeWaitsForNotificationDrainAfterTransportReturns() async throws {
        let transport = EarlyReturningTerminationTransport()
        let callbackStarted = AsyncGate()
        let releaseCallback = AsyncGate()
        let closeReturned = RegressionFlag()
        let connection = ACPConnection(
            transport: transport,
            handlers: ACPConnectionHandlers(onNotification: { _, _, _ in
                await callbackStarted.open()
                await releaseCallback.wait()
            })
        )
        try await connection.start()
        await transport.emit(.notification(method: "event", params: nil))
        await callbackStarted.wait()

        let close = Task {
            await connection.close()
            await closeReturned.set()
        }
        #expect(!(await eventually(for: .milliseconds(100)) { await closeReturned.value }))

        await releaseCallback.open()
        await close.value
        #expect(await closeReturned.value)
    }
}
