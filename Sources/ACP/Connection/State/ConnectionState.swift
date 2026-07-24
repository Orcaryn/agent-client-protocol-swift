import ACPModel

enum ConnectionPhase {
    case idle
    case running
    case closing
    case draining
    case closed
}

struct ConnectionPendingRequest: Sendable {
    let complete: @Sendable (Result<ACPValue, Error>) -> Void
    let waitsForPrecedingNotifications: Bool
    let sendTask: Task<Void, Error>
    var sent = false
    var cancellationRequested = false
    var timeoutTask: Task<Void, Never>?
}

struct ConnectionOutboundState {
    private var nextRequestID: Int64 = 1
    var pending: [ACPRequestID: ConnectionPendingRequest] = [:]

    mutating func allocateRequestID() -> ACPRequestID {
        defer { nextRequestID += 1 }
        return .integer(nextRequestID)
    }
}

struct ConnectionInboundState {
    var activeRequests: [ACPRequestID: Task<Void, Never>] = [:]
    var notificationTail: Task<Void, Never>?
    var nextNotificationSequence: UInt64 = 1
    var activeNotificationSequence: UInt64?
}

struct ConnectionLifecycleState {
    var phase = ConnectionPhase.idle
    var termination: ACPTransportTermination?
    var closeWaiters: [CheckedContinuation<ACPTransportTermination, Never>] = []
    var sendTail: Task<Void, Never>?
}

enum ACPNotificationContext {
    @TaskLocal static var sequence: UInt64?
}

func validatedRequestTimeout(_ timeout: Duration?) -> Duration? {
    if let timeout {
        precondition(timeout >= .zero, "requestTimeout must not be negative")
    }
    return timeout
}
