import ACPModel

struct ACPInboundRequestRouting: Sendable {
    typealias Receiver = @Sendable (ACPRequestID, String, ACPValue?) async -> Void
    typealias Handler =
        @Sendable (ACPConnection, ACPRequestID, String, ACPValue?) async throws -> ACPValue
    typealias Finisher = @Sendable (ACPRequestID) async -> Void

    let received: Receiver?
    let handle: Handler
    let finished: Finisher?

    init(
        received: Receiver? = nil,
        handle: @escaping Handler,
        finished: Finisher? = nil
    ) {
        self.received = received
        self.handle = handle
        self.finished = finished
    }
}
