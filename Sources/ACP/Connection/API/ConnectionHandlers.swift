import ACPModel

public struct ACPConnectionHandlers: Sendable {
    public typealias NotificationHandler = @Sendable (ACPConnection, String, ACPValue?) async -> Void
    public typealias RequestHandler = @Sendable (ACPConnection, String, ACPValue?) async throws -> ACPValue
    public typealias LogHandler = @Sendable (String) async -> Void
    public typealias TerminationHandler = @Sendable (ACPTransportTermination) async -> Void

    public let onNotification: NotificationHandler?
    public let onRequest: RequestHandler?
    public let onLog: LogHandler?
    public let onTermination: TerminationHandler?
    public let wireInspection: ACPWireInspection?

    public init(
        onNotification: NotificationHandler? = nil,
        onRequest: RequestHandler? = nil,
        onLog: LogHandler? = nil,
        onTermination: TerminationHandler? = nil,
        wireInspection: ACPWireInspection? = nil
    ) {
        self.onNotification = onNotification
        self.onRequest = onRequest
        self.onLog = onLog
        self.onTermination = onTermination
        self.wireInspection = wireInspection
    }
}
