import ACP
import ACPModel

extension Collection where Element == ACPJSONRPCMessage {
    func requestID(for method: String) -> ACPRequestID? {
        for case .request(let id, let receivedMethod, _) in self where receivedMethod == method {
            return id
        }
        return nil
    }
}

actor ControlledConnectionTransport: ACPMessageTransport {
    private typealias Waiter = (
        count: Int,
        continuation: CheckedContinuation<[ACPJSONRPCMessage], Never>
    )

    private var onMessage: ACPMessageHandler?
    private var onTermination: ACPTerminationHandler?
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var messages: [ACPJSONRPCMessage] = []
    private var waiters: [Waiter] = []
    private var nextSendError: (any Error)?
    private(set) var terminationCount = 0

    func start(
        onMessage: @escaping ACPMessageHandler,
        onLog _: @escaping ACPLogHandler,
        onTermination: @escaping ACPTerminationHandler
    ) {
        self.onMessage = onMessage
        self.onTermination = onTermination

        let waiters = startWaiters
        startWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }

    func send(_ message: ACPJSONRPCMessage) throws {
        if let error = nextSendError {
            nextSendError = nil
            throw error
        }

        messages.append(message)
        resumeReadyWaiters()
    }

    func terminate() async {
        terminationCount += 1
        await finish(.terminated)
    }

    func emit(_ message: ACPJSONRPCMessage) async {
        await onMessage?(message)
    }

    func waitUntilStarted() async {
        if onMessage != nil {
            return
        }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func sentMessages() -> [ACPJSONRPCMessage] {
        messages
    }

    func finish(_ reason: ACPTransportTermination) async {
        await onTermination?(reason)
    }

    func failNextSend(with error: any Error) {
        nextSendError = error
    }

    func waitForMessages(_ count: Int) async -> [ACPJSONRPCMessage] {
        if messages.count >= count {
            return messages
        }

        return await withCheckedContinuation { continuation in
            waiters.append((count, continuation))
        }
    }

    private func resumeReadyWaiters() {
        let ready = waiters.filter { messages.count >= $0.count }
        waiters.removeAll { messages.count >= $0.count }
        for waiter in ready {
            waiter.continuation.resume(returning: messages)
        }
    }
}
