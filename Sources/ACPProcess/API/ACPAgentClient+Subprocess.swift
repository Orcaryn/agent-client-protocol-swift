import ACP
import ACPModel

public extension ACPAgentClient {
    init(
        launch: ACPProcessLaunch,
        clientCapabilities: ACPClientCapabilities = .acpDefault,
        clientInfo: ACPImplementationInfo? = nil,
        callbacks: ACPAgentClientCallbacks = ACPAgentClientCallbacks(),
        maximumFrameBytes: Int = ACPTransportDefaults.maximumFrameBytes,
        terminationGracePeriod: Duration = .milliseconds(100),
        onRawMessage: ACPRawMessageHandler? = nil,
        wireInspection: ACPWireInspection? = nil,
        requestTimeout: Duration? = nil
    ) {
        self.init(
            transport: ACPSubprocessTransport(
                launch: launch,
                maximumFrameBytes: maximumFrameBytes,
                terminationGracePeriod: terminationGracePeriod,
                onRawMessage: onRawMessage
            ),
            clientCapabilities: clientCapabilities,
            clientInfo: clientInfo,
            callbacks: callbacks,
            wireInspection: wireInspection,
            requestTimeout: requestTimeout
        )
    }
}
