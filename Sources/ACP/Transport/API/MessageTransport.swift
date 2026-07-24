import ACPModel

import Foundation

public enum ACPTransportDefaults {
    /// A generous ceiling that still prevents an unterminated frame from growing without bound.
    public static let maximumFrameBytes = 64 * 1024 * 1024
}

public enum ACPTransportTermination: Error, Equatable, LocalizedError, Sendable {
    case endOfFile
    case terminated
    case processExited(Int32)
    case invalidMessage(String)

    public var errorDescription: String? {
        switch self {
        case .endOfFile:
            "The ACP transport reached end of file."
        case .terminated:
            "The ACP transport was terminated."
        case .processExited(let status):
            "The ACP process exited with status \(status)."
        case .invalidMessage(let detail):
            "The ACP transport received an invalid message: \(detail)"
        }
    }
}

public enum ACPTransportError: Error, Equatable, LocalizedError, Sendable {
    case alreadyStarted
    case notStarted
    case closed

    public var errorDescription: String? {
        switch self {
        case .alreadyStarted:
            "The ACP transport has already started."
        case .notStarted:
            "The ACP transport has not started."
        case .closed:
            "The ACP transport is closed."
        }
    }
}

public typealias ACPMessageHandler = @Sendable (ACPJSONRPCMessage) async -> Void
public typealias ACPLogHandler = @Sendable (String) async -> Void
public typealias ACPTerminationHandler = @Sendable (ACPTransportTermination) async -> Void

public enum ACPRawMessageDirection: String, Sendable {
    case clientToAgent = "client_to_agent"
    case agentToClient = "agent_to_client"
}

public typealias ACPRawMessageHandler = @Sendable (ACPRawMessageDirection, Data) async -> Void

public protocol ACPMessageTransport: Sendable {
    func start(
        onMessage: @escaping ACPMessageHandler,
        onLog: @escaping ACPLogHandler,
        onTermination: @escaping ACPTerminationHandler
    ) async throws

    func send(_ message: ACPJSONRPCMessage) async throws
    func terminate() async
}
