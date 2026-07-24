import ACPModel

public actor ACPAgentClient {
    public private(set) var initialization: ACPInitializeResponse?

    private let clientCapabilities: ACPClientCapabilities
    private let clientInfo: ACPImplementationInfo?
    let runtime: ClientRuntime
    let connection: ACPConnection

    public init(
        transport: any ACPMessageTransport,
        clientCapabilities: ACPClientCapabilities = .acpDefault,
        clientInfo: ACPImplementationInfo? = nil,
        callbacks: ACPAgentClientCallbacks = ACPAgentClientCallbacks(),
        wireInspection: ACPWireInspection? = nil,
        requestTimeout: Duration? = nil
    ) {
        let runtime = ClientRuntime(
            capabilities: clientCapabilities,
            callbacks: callbacks
        )
        let eventHandler: @Sendable (ACPAgentClientEvent) async -> Void = {
            await runtime.events.emit($0)
        }
        let clientWireInspection = wireInspection?.addingEventHandler { event in
            await eventHandler(.wire(event))
        }

        self.clientCapabilities = clientCapabilities
        self.runtime = runtime
        connection = ACPConnection(
            transport: transport,
            handlers: ClientInboundRouter(
                runtime: runtime,
                events: eventHandler,
                wireInspection: clientWireInspection
            ).connectionHandlers,
            requestTimeout: requestTimeout
        )
        self.clientInfo = clientInfo
    }

    /// Returns a bounded stream of one-way client events.
    ///
    /// Each subscriber has its own newest-event buffer. If that buffer overflows, the
    /// subscriber receives ``ACPAgentClientEvent/overflow`` and its stream finishes;
    /// other subscribers are unaffected. The stream also finishes when the connection
    /// terminates.
    ///
    /// Callbacks supplied when creating the client are awaited directly and remain the
    /// lossless delivery path. Request/response interactions are always callback based.
    ///
    /// - Precondition: `limit` must be greater than zero.
    public func events(bufferingNewest limit: Int = 100) async -> AsyncStream<ACPAgentClientEvent> {
        await runtime.events.stream(bufferingNewest: limit)
    }

    @discardableResult
    public func connect(_meta: ACPMeta? = nil) async throws -> ACPInitializeResponse {
        try await connection.start()
        do {
            let response: ACPInitializeResponse = try await connection.request(
                method: ACPProtocol.Method.initialize,
                params: ACPInitializeRequest(
                    clientCapabilities: clientCapabilities,
                    clientInfo: clientInfo,
                    _meta: _meta
                )
            )
            guard response.protocolVersion == ACPProtocol.version else {
                throw ACPAgentClientError.protocolVersionMismatch(
                    expected: ACPProtocol.version,
                    received: response.protocolVersion
                )
            }
            initialization = response
            return response
        } catch {
            await connection.close()
            initialization = nil
            throw error
        }
    }

    public func authenticate(methodID: String, _meta: ACPMeta? = nil) async throws {
        guard try initialized().authMethods.contains(where: { $0.id == methodID }) else {
            throw ACPJSONRPCError.invalidParams
        }
        let _: ACPEmptyResponse = try await connection.request(
            method: ACPProtocol.Method.authenticate,
            params: ACPAuthenticateRequest(methodID: methodID, _meta: _meta)
        )
    }

    public func logout(_meta: ACPMeta? = nil) async throws {
        guard try initialized().agentCapabilities.auth.logout != nil else {
            throw ACPJSONRPCError.methodNotFound
        }
        let _: ACPLogoutResponse = try await connection.request(
            method: ACPProtocol.Method.logout,
            params: ACPLogoutRequest(_meta: _meta)
        )
    }

    public func shutdown() async {
        await connection.close()
        initialization = nil
    }

    /// Waits for transport termination and all connection callbacks to drain.
    public func waitUntilClosed() async -> ACPTransportTermination {
        let termination = await connection.waitUntilClosed()
        initialization = nil
        return termination
    }

    func initialized() throws -> ACPInitializeResponse {
        guard let initialization else { throw ACPAgentClientError.notInitialized }
        return initialization
    }

    func validateConfigOptions(_ options: [ACPSessionConfigOption]?) throws {
        try ConfigurationValidator.validate(
            options,
            clientCapabilities: clientCapabilities
        )
    }
}
