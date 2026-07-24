import ACPTestSupport
import Testing

@testable import ACP
import ACPModel

actor ClientLogs {
    private(set) var messages: [String] = []

    func record(_ message: String) {
        messages.append(message)
    }
}

func connectedClient(
    transport: ControlledConnectionTransport,
    capabilities: ACPAgentCapabilities,
    callbacks: ACPAgentClientCallbacks
) async throws -> ACPAgentClient {
    let client = ACPAgentClient(
        transport: transport,
        callbacks: callbacks
    )
    let connect = Task { try await client.connect() }
    try await respond(
        to: ACPProtocol.Method.initialize,
        after: 1,
        with: ACPInitializeResponse(
            protocolVersion: ACPProtocol.version,
            agentCapabilities: capabilities
        ),
        using: transport
    )
    _ = try await connect.value

    return client
}

func respond<Response: Encodable & Sendable>(
    to method: String,
    after messageCount: Int,
    with response: Response,
    using transport: ControlledConnectionTransport
) async throws {
    let id = try #require(
        await transport.waitForMessages(messageCount).requestID(for: method)
    )
    await transport.emit(.response(id: id, result: try ACPValue.encode(response)))
}

func modelConfigOption(currentValue: String) -> ACPSessionConfigOption {
    .select(
        ACPSessionConfigSelect(
            id: "model",
            name: "Model",
            currentValue: currentValue,
            options: .ungrouped([
                ACPSessionConfigSelectOption(value: "fast", name: "Fast"),
                ACPSessionConfigSelectOption(value: "smart", name: "Smart"),
            ]),
            category: .model
        )
    )
}

func sessionModes(currentModeID: String) -> ACPSessionModeState {
    ACPSessionModeState(
        currentModeID: currentModeID,
        availableModes: [
            ACPSessionMode(id: "code", name: "Code"),
            ACPSessionMode(id: "review", name: "Review"),
        ]
    )
}

func blockingUpdateClient(
    capabilities: ACPAgentCapabilities
) async throws -> (
    client: ACPAgentClient,
    transport: ControlledConnectionTransport,
    updateStarted: AsyncGate,
    releaseUpdate: AsyncGate
) {
    let updateStarted = AsyncGate()
    let releaseUpdate = AsyncGate()
    let transport = ControlledConnectionTransport()
    let client = try await connectedClient(
        transport: transport,
        capabilities: capabilities,
        callbacks: ACPAgentClientCallbacks(
            session: ACPClientSessionCallbacks(
                update: { _ in
                    await updateStarted.open()
                    await releaseUpdate.wait()
                }
            )
        )
    )
    return (client, transport, updateStarted, releaseUpdate)
}

func establishSession(
    client: ACPAgentClient,
    transport: ControlledConnectionTransport,
    modes: ACPSessionModeState? = nil,
    configOptions: [ACPSessionConfigOption]? = nil
) async throws {
    let newSession = Task { try await client.newSession(cwd: "/workspace") }
    try await respond(
        to: ACPProtocol.Method.sessionNew,
        after: 2,
        with: ACPNewSessionResponse(
            sessionID: "session",
            modes: modes,
            configOptions: configOptions
        ),
        using: transport
    )
    _ = try await newSession.value
}

func emitSessionUpdate(
    _ update: ACPSessionUpdate,
    using transport: ControlledConnectionTransport
) async throws {
    await transport.emit(
        .notification(
            method: ACPProtocol.Method.sessionUpdate,
            params: try ACPValue.encode(
                ACPSessionNotification(sessionID: "session", update: update)
            )
        )
    )
}

func blockNotificationQueue(
    using transport: ControlledConnectionTransport,
    until updateStarted: AsyncGate
) async throws {
    try await emitSessionUpdate(
        .agentMessageChunk(
            ACPContentChunk(content: .text(ACPTextContent(text: "preceding")))
        ),
        using: transport
    )
    await updateStarted.wait()
}
