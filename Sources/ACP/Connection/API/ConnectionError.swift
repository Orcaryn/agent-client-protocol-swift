import Foundation

public enum ACPConnectionError: Error, Equatable, LocalizedError, Sendable {
    case closed
    case requestTimedOut(method: String)

    public var errorDescription: String? {
        switch self {
        case .closed:
            "The ACP connection is closed."
        case .requestTimedOut(let method):
            "ACP request '\(method)' timed out."
        }
    }
}
