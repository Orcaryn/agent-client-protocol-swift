import ACPModel

struct WireEventRecorder {
    private let inspection: ACPWireInspection?
    private var outboundMethods: [ACPRequestID: String] = [:]
    private var inboundMethods: [ACPRequestID: String] = [:]
    private var eventTail: Task<Void, Never>?

    init(inspection: ACPWireInspection?) {
        self.inspection = inspection
    }

    mutating func receive(_ message: ACPJSONRPCMessage) {
        if case .request(let id, let method, _) = message {
            inboundMethods[id] = method
        }
        emit(message, direction: .incoming)
        if let id = message.responseID {
            outboundMethods[id] = nil
        }
    }

    mutating func willSend(_ message: ACPJSONRPCMessage) {
        if case .request(let id, let method, _) = message {
            outboundMethods[id] = method
        }
    }

    mutating func didSend(_ message: ACPJSONRPCMessage) {
        emit(message, direction: .outgoing)
        if let id = message.responseID {
            inboundMethods[id] = nil
        }
    }

    mutating func sendFailed(_ message: ACPJSONRPCMessage) {
        if case .request(let id, _, _) = message {
            outboundMethods[id] = nil
        }
    }

    mutating func finish() -> Task<Void, Never>? {
        outboundMethods.removeAll()
        inboundMethods.removeAll()
        defer { eventTail = nil }
        return eventTail
    }

    private mutating func emit(
        _ message: ACPJSONRPCMessage,
        direction: ACPWireDirection
    ) {
        guard let inspection, let handler = inspection.onEvent else { return }
        let method: String?
        if let id = message.responseID {
            method = direction == .incoming ? outboundMethods[id] : inboundMethods[id]
        } else {
            method = message.method
        }

        let event = inspection.makeEvent(for: message, direction: direction, method: method)
        let previous = eventTail
        eventTail = Task {
            await previous?.value
            await handler(event)
        }
    }
}

private extension ACPJSONRPCMessage {
    var method: String? {
        switch self {
        case .request(_, let method, _), .notification(let method, _): method
        case .response, .error: nil
        }
    }

    var responseID: ACPRequestID? {
        switch self {
        case .response(let id, _), .error(let id, _): id
        case .request, .notification: nil
        }
    }
}
