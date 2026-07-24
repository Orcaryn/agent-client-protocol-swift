import Foundation

public enum ACPAgentClientError: Error, Equatable, LocalizedError, Sendable {
    case notInitialized
    case sessionNotEstablished(String)
    case protocolVersionMismatch(expected: UInt16, received: UInt16)

    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            "The ACP client has not been initialized."
        case .sessionNotEstablished(let sessionID):
            "ACP session '\(sessionID)' has not been established."
        case .protocolVersionMismatch(let expected, let received):
            "ACP protocol version mismatch: expected \(expected), received \(received)."
        }
    }
}
