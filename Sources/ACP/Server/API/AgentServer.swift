public actor ACPAgentServer {
    private let connection: ACPConnection

    public init(
        transport: any ACPMessageTransport = ACPStandardIOTransport(),
        handlers: ACPAgentServerHandlers,
        wireInspection: ACPWireInspection? = nil,
        requestTimeout: Duration? = nil
    ) {
        let runtime = AgentRuntime(handlers: handlers)
        let router = AgentInboundRouter(
            runtime: runtime,
            wireInspection: wireInspection
        )
        connection = ACPConnection(
            transport: transport,
            handlers: router.connectionHandlers,
            requestRouting: router.requestRouting,
            requestTimeout: requestTimeout
        )
    }

    public func run() async throws -> ACPTransportTermination {
        try await connection.start()
        return await connection.waitUntilClosed()
    }

    public func shutdown() async {
        await connection.close()
    }
}
