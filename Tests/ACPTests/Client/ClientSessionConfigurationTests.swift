import Testing

@testable import ACP
import ACPModel

struct ACPAgentClientTests {
    @Test func setConfigResponseWinsOverEarlierQueuedUpdate() async throws {
        let state = try await blockingUpdateClient(capabilities: ACPAgentCapabilities())
        try await establishSession(
            client: state.client,
            transport: state.transport,
            configOptions: [modelConfigOption(currentValue: "fast")]
        )
        let setConfig = Task {
            try await state.client.setConfigOption(
                sessionID: "session",
                configID: "model",
                value: .valueID("smart")
            )
        }
        try await blockNotificationQueue(
            using: state.transport,
            until: state.updateStarted
        )
        try await emitSessionUpdate(
            .configOptionUpdate(
                ACPConfigOptionUpdate(
                    configOptions: [modelConfigOption(currentValue: "fast")]
                )
            ),
            using: state.transport
        )
        try await respond(
            to: ACPProtocol.Method.sessionSetConfigOption,
            after: 3,
            with: ACPSetConfigOptionResponse(
                configOptions: [modelConfigOption(currentValue: "smart")]
            ),
            using: state.transport
        )

        await state.releaseUpdate.open()
        _ = try await setConfig.value
        #expect(
            try await state.client.sessionSnapshot(sessionID: "session").configOptions
                == [modelConfigOption(currentValue: "smart")]
        )
        await state.client.shutdown()
    }
    @Test func setModeResponseWinsOverEarlierQueuedUpdate() async throws {
        let state = try await blockingUpdateClient(capabilities: ACPAgentCapabilities())
        try await establishSession(
            client: state.client,
            transport: state.transport,
            modes: sessionModes(currentModeID: "code")
        )
        let setMode = Task {
            try await state.client.setMode(sessionID: "session", modeID: "review")
        }
        try await blockNotificationQueue(
            using: state.transport,
            until: state.updateStarted
        )
        try await emitSessionUpdate(
            .currentModeUpdate(ACPCurrentModeUpdate(currentModeID: "code")),
            using: state.transport
        )
        try await respond(
            to: ACPProtocol.Method.sessionSetMode,
            after: 3,
            with: ACPEmptyResponse(),
            using: state.transport
        )

        await state.releaseUpdate.open()
        try await setMode.value
        #expect(
            try await state.client.sessionSnapshot(sessionID: "session").modes?.currentModeID
                == "review"
        )
        await state.client.shutdown()
    }
    @Test func sessionConfigurationRejectsDuplicateModeIdentifiers() async {
        let registry = SessionRegistry(role: .client)

        await #expect(throws: ACPJSONRPCError.invalidParams) {
            try await registry.register(
                sessionID: "session",
                cwd: "/workspace",
                additionalDirectories: nil,
                modes: ACPSessionModeState(
                    currentModeID: "code",
                    availableModes: [
                        ACPSessionMode(id: "code", name: "Code"),
                        ACPSessionMode(id: "code", name: "Duplicate"),
                    ]
                )
            )
        }
    }
}
