import Testing

@testable import ACP
import ACPModel

private actor ClientEventTransport: ACPMessageTransport {
    private var onMessage: ACPMessageHandler?
    private var onLog: ACPLogHandler?
    private var onTermination: ACPTerminationHandler?
    private var sent: [ACPJSONRPCMessage] = []

    func start(
        onMessage: @escaping ACPMessageHandler,
        onLog: @escaping ACPLogHandler,
        onTermination: @escaping ACPTerminationHandler
    ) {
        self.onMessage = onMessage
        self.onLog = onLog
        self.onTermination = onTermination
    }

    func send(_ message: ACPJSONRPCMessage) {
        sent.append(message)
    }

    func terminate() async {
        await onTermination?(.terminated)
    }

    func emit(_ message: ACPJSONRPCMessage) async { await onMessage?(message) }
    func emitLog(_ log: String) async { await onLog?(log) }

    func waitForRequest(_ method: String) async -> ACPRequestID {
        while true {
            if let id = sent.requestID(for: method) { return id }
            await Task.yield()
        }
    }
}

private actor WireEventRecorder {
    private(set) var events: [ACPWireEvent] = []

    func record(_ event: ACPWireEvent) {
        events.append(event)
    }
}

struct ACPAgentClientEventTests {
    @Test func overflowIsExplicitAndFinishesOnlyTheSlowSubscriber() async {
        let source = ACPAgentClientEventStream()
        let slow = await source.stream(bufferingNewest: 1)
        let fast = await source.stream(bufferingNewest: 1)
        var fastIterator = fast.makeAsyncIterator()

        await source.emit(.log("one"))
        #expect(await fastIterator.next() == .log("one"))

        await source.emit(.log("two"))
        var slowEvents: [ACPAgentClientEvent] = []
        for await event in slow {
            slowEvents.append(event)
        }
        #expect(slowEvents == [.overflow])
        #expect(await fastIterator.next() == .log("two"))

        await source.emit(.log("three"))
        #expect(await fastIterator.next() == .log("three"))
        await source.emit(.terminated(.endOfFile))
        #expect(await fastIterator.next() == .terminated(.endOfFile))
        #expect(await fastIterator.next() == nil)
    }

    @Test func eventStreamCarriesUpdatesLogsAndTerminationThenFinishes() async throws {
        let transport = ClientEventTransport()
        let client = ACPAgentClient(transport: transport)
        let stream = await client.events(bufferingNewest: 8)
        let collected = Task { () -> [ACPAgentClientEvent] in
            var events: [ACPAgentClientEvent] = []
            for await event in stream { events.append(event) }
            return events
        }

        let connect = Task { try await client.connect() }
        let initializeID = await transport.waitForRequest(ACPProtocol.Method.initialize)
        await transport.emit(
            .response(
                id: initializeID,
                result: try ACPValue.encode(
                    ACPInitializeResponse(
                        protocolVersion: ACPProtocol.version,
                        agentCapabilities: ACPAgentCapabilities()
                    )
                )
            )
        )
        _ = try await connect.value

        let create = Task { try await client.newSession(cwd: "/workspace") }
        let newSessionID = await transport.waitForRequest(ACPProtocol.Method.sessionNew)
        await transport.emit(
            .response(
                id: newSessionID,
                result: try ACPValue.encode(ACPNewSessionResponse(sessionID: "session"))
            )
        )
        _ = try await create.value

        let notification = ACPSessionNotification(
            sessionID: "session",
            update: .agentMessageChunk(
                ACPContentChunk(content: .text(ACPTextContent(text: "hello")))
            )
        )
        await transport.emit(
            .notification(
                method: ACPProtocol.Method.sessionUpdate,
                params: try ACPValue.encode(notification)
            )
        )
        await transport.emitLog("agent stderr")
        let waitForClose = Task { await client.waitUntilClosed() }
        await client.shutdown()
        #expect(await waitForClose.value == .terminated)

        let events = await collected.value
        #expect(events.count == 3)
        #expect(events.contains(.sessionUpdate(notification)))
        #expect(events.contains(.log("agent stderr")))
        #expect(events.last == .terminated(.terminated))
    }

    @Test func wireInspectionRedactsPayloadAndCorrelatesResponses() async throws {
        let recorder = WireEventRecorder()
        let transport = ControlledConnectionTransport()
        let connection = ACPConnection(
            transport: transport,
            handlers: ACPConnectionHandlers(
                wireInspection: ACPWireInspection(onEvent: { event in
                    await recorder.record(event)
                })
            )
        )
        try await connection.start()

        let request = Task {
            try await connection.request(
                method: "_vendor/login",
                params: ACPValue.object([
                    "api-key": .string("do-not-expose"),
                    "nested": .object(["refresh_token": .string("also-secret")]),
                    "safe": .string("visible"),
                ]),
                response: String.self
            )
        }
        let sent = await transport.waitForMessages(1)
        let id = try #require(sent.requestID(for: "_vendor/login"))
        await transport.emit(.response(id: id, result: .string("ok")))
        #expect(try await request.value == "ok")
        await connection.close()

        let events = await recorder.events
        #expect(events.count == 2)
        #expect(events[0].direction == .outgoing)
        #expect(events[0].kind == .request)
        #expect(events[0].requestID == id)
        #expect(events[0].method == "_vendor/login")
        #expect(events[0].rawJSON?.contains("do-not-expose") == false)
        #expect(events[0].rawJSON?.contains("also-secret") == false)
        #expect(events[0].rawJSON?.contains("<redacted>") == true)
        #expect(events[0].rawJSON?.contains("visible") == true)

        #expect(events[1].direction == .incoming)
        #expect(events[1].kind == .response)
        #expect(events[1].requestID == id)
        #expect(events[1].method == "_vendor/login")
    }

    @Test func wireInspectionOmitsPayloadAboveConfiguredLimit() async throws {
        let recorder = WireEventRecorder()
        let transport = ControlledConnectionTransport()
        let connection = ACPConnection(
            transport: transport,
            handlers: ACPConnectionHandlers(
                wireInspection: ACPWireInspection(
                    maximumRawJSONBytes: 1,
                    onEvent: { event in await recorder.record(event) }
                )
            )
        )
        try await connection.start()
        try await connection.notify(method: "_vendor/event", params: ["value": "content"])
        await connection.close()

        let event = try #require(await recorder.events.first)
        #expect(event.rawJSON == nil)
        #expect(event.payloadOmitted)
    }
}
