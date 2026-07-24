import ACPTestSupport
import Foundation
import Testing

@testable import ACP
import ACPModel

enum ConnectionTestFailure: Error, Equatable, LocalizedError {
    case write
    case handler

    var errorDescription: String? {
        switch self {
        case .write: "write failed"
        case .handler: "handler failed"
        }
    }
}

actor ConnectionTestEvents {
    private(set) var values: [String] = []

    func append(_ value: String) {
        values.append(value)
    }
}

actor BlockingSendTransport: ACPMessageTransport {
    private let sendStarted = AsyncGate()
    private let releaseSend = AsyncGate()
    private var onTermination: ACPTerminationHandler?

    func start(
        onMessage _: @escaping ACPMessageHandler,
        onLog _: @escaping ACPLogHandler,
        onTermination: @escaping ACPTerminationHandler
    ) {
        self.onTermination = onTermination
    }

    func send(_: ACPJSONRPCMessage) async {
        await sendStarted.open()
        await releaseSend.wait()
    }

    func terminate() async {
        await finish(.terminated)
    }

    func waitUntilSendStarts() async {
        await sendStarted.wait()
    }

    func releaseBlockedSend() async {
        await releaseSend.open()
    }

    func finish(_ termination: ACPTransportTermination) async {
        await onTermination?(termination)
    }
}
