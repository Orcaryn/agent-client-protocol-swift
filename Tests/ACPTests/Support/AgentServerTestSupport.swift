import Testing

@testable import ACP
import ACPModel

actor AgentServerRoutes {
    private var values: Set<String> = []

    func record(_ value: String) {
        values.insert(value)
    }

    func snapshot() -> Set<String> {
        values
    }
}

actor ScriptedAgentTransport: ACPMessageTransport {
    private let expectedResponseCount: Int
    private var onMessage: ACPMessageHandler?
    private var onTermination: ACPTerminationHandler?
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var messages: [ACPJSONRPCMessage] = []
    private var didTerminate = false

    init(expectedResponseCount: Int) {
        self.expectedResponseCount = expectedResponseCount
    }

    func start(
        onMessage: @escaping ACPMessageHandler,
        onLog: @escaping ACPLogHandler,
        onTermination: @escaping ACPTerminationHandler
    ) async throws {
        self.onMessage = onMessage
        self.onTermination = onTermination

        let waiters = startWaiters
        startWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }

    func send(_ message: ACPJSONRPCMessage) async {
        messages.append(message)

        if messages.count == expectedResponseCount {
            await finish(.endOfFile)
        }
    }

    func terminate() async {
        await finish(.terminated)
    }

    func waitUntilStarted() async {
        if onMessage != nil {
            return
        }

        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func receive(_ message: ACPJSONRPCMessage) async {
        if let onMessage {
            await onMessage(message)
        }
    }

    func sentMessages() -> [ACPJSONRPCMessage] {
        messages
    }

    private func finish(_ termination: ACPTransportTermination) async {
        if didTerminate {
            return
        }

        didTerminate = true
        await onTermination?(termination)
    }
}

actor ServerWireEvents {
    private(set) var values: [ACPWireEvent] = []

    func record(_ event: ACPWireEvent) {
        values.append(event)
    }
}

func request<Params: Encodable>(
    _ id: Int64,
    _ method: String,
    _ params: Params
) throws -> ACPJSONRPCMessage {
    .request(id: .integer(id), method: method, params: try ACPValue.encode(params))
}

func notification<Params: Encodable>(
    method: String,
    params: Params
) throws -> ACPJSONRPCMessage {
    .notification(method: method, params: try ACPValue.encode(params))
}
