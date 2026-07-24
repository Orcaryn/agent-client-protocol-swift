import Testing

@testable import ACP
import ACPModel

actor RegressionFlag {
    private(set) var value = false

    func set() {
        value = true
    }
}

actor RegressionCounter {
    private(set) var value = 0

    @discardableResult
    func increment() -> Int {
        value += 1
        return value
    }
}

actor RegressionEvents {
    private(set) var values: [String] = []

    func append(_ value: String) {
        values.append(value)
    }
}

actor EarlyReturningTerminationTransport: ACPMessageTransport {
    private var onMessage: ACPMessageHandler?
    private var onTermination: ACPTerminationHandler?

    func start(
        onMessage: @escaping ACPMessageHandler,
        onLog _: @escaping ACPLogHandler,
        onTermination: @escaping ACPTerminationHandler
    ) {
        self.onMessage = onMessage
        self.onTermination = onTermination
    }

    func send(_: ACPJSONRPCMessage) {}

    func terminate() {
        guard let onTermination else { return }
        Task { await onTermination(.terminated) }
    }

    func emit(_ message: ACPJSONRPCMessage) async {
        await onMessage?(message)
    }
}

func connectRegressionClient(
    _ client: ACPAgentClient,
    transport: ControlledConnectionTransport,
    capabilities: ACPAgentCapabilities
) async throws {
    let connect = Task { try await client.connect() }
    let id = try #require(
        await transport.waitForMessages(1).requestID(for: ACPProtocol.Method.initialize)
    )
    await transport.emit(
        .response(
            id: id,
            result: try ACPValue.encode(
                ACPInitializeResponse(
                    protocolVersion: ACPProtocol.version,
                    agentCapabilities: capabilities
                )
            )
        )
    )
    _ = try await connect.value
}

func establishRegressionSession(
    using transport: ControlledConnectionTransport,
    clientCapabilities: ACPClientCapabilities = .acpDefault
) async throws {
    await transport.emit(
        .request(
            id: .integer(1),
            method: ACPProtocol.Method.initialize,
            params: try ACPValue.encode(
                ACPInitializeRequest(clientCapabilities: clientCapabilities)
            )
        )
    )
    _ = await transport.waitForMessages(1)
    await transport.emit(
        .request(
            id: .integer(2),
            method: ACPProtocol.Method.sessionNew,
            params: try ACPValue.encode(ACPNewSessionRequest(cwd: "/workspace"))
        )
    )
    _ = await transport.waitForMessages(2)
}

func sendRegressionPrompt(using transport: ControlledConnectionTransport) async throws {
    await transport.emit(
        .request(
            id: .integer(3),
            method: ACPProtocol.Method.sessionPrompt,
            params: try ACPValue.encode(
                ACPPromptRequest(
                    sessionID: "session",
                    prompt: [.text(ACPTextContent(text: "hello"))]
                )
            )
        )
    )
}

func acceptRegressionTerminal(using transport: ControlledConnectionTransport) async throws {
    let createID = try #require(
        await transport.waitForMessages(3).requestID(for: ACPProtocol.Method.terminalCreate)
    )
    await transport.emit(
        .response(
            id: createID,
            result: try ACPValue.encode(ACPCreateTerminalResponse(terminalID: "terminal"))
        )
    )
}
