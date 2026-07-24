import ACP

public extension ACPConnection {
    init(
        launch: ACPProcessLaunch,
        maximumFrameBytes: Int = ACPTransportDefaults.maximumFrameBytes,
        terminationGracePeriod: Duration = .milliseconds(100),
        onRawMessage: ACPRawMessageHandler? = nil,
        handlers: ACPConnectionHandlers = ACPConnectionHandlers(),
        requestTimeout: Duration? = nil
    ) {
        self.init(
            transport: ACPSubprocessTransport(
                launch: launch,
                maximumFrameBytes: maximumFrameBytes,
                terminationGracePeriod: terminationGracePeriod,
                onRawMessage: onRawMessage
            ),
            handlers: handlers,
            requestTimeout: requestTimeout
        )
    }
}
