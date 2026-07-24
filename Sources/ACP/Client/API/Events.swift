import ACPModel

import Foundation

/// A one-way event emitted by an ``ACPAgentClient``.
///
/// Requests that require a response, such as permission and filesystem requests,
/// continue to use ``ACPAgentClientCallbacks``.
public enum ACPAgentClientEvent: Sendable, Equatable {
    case sessionUpdate(ACPSessionNotification)
    case log(String)
    case terminated(ACPTransportTermination)
    case wire(ACPWireEvent)

    /// The subscriber could not keep up with its configured buffer and the stream ended.
    case overflow
}

actor ACPAgentClientEventStream {
    private var continuations: [UUID: AsyncStream<ACPAgentClientEvent>.Continuation] = [:]
    private var finished = false

    func stream(bufferingNewest limit: Int) -> AsyncStream<ACPAgentClientEvent> {
        precondition(limit > 0, "Event stream buffer limit must be greater than zero")
        let id = UUID()
        return AsyncStream(bufferingPolicy: .bufferingNewest(limit)) { continuation in
            guard !finished else {
                continuation.finish()
                return
            }

            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.remove(id) }
            }
        }
    }

    func emit(_ event: ACPAgentClientEvent) {
        var inactive: [UUID] = []
        for (id, continuation) in continuations {
            switch continuation.yield(event) {
            case .enqueued:
                break
            case .dropped:
                continuation.yield(.overflow)
                continuation.finish()
                inactive.append(id)
            case .terminated:
                inactive.append(id)
            @unknown default:
                continuation.finish()
                inactive.append(id)
            }
        }
        for id in inactive {
            continuations[id] = nil
        }
        if case .terminated = event {
            finish()
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        let activeContinuations = continuations.values
        continuations.removeAll()
        for continuation in activeContinuations {
            continuation.finish()
        }
    }

    private func remove(_ id: UUID) {
        continuations[id] = nil
    }
}
