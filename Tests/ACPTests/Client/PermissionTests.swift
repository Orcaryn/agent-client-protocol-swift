import ACPTestSupport
import Testing

@testable import ACP
import ACPModel

extension ACPAgentClientTests {
    @Test func cancellingPermissionDoesNotWaitForHandlerCooperation() async throws {
        let coordinator = ACPPermissionCoordinator()
        let gate = AsyncGate()
        let started = ClientLogs()
        let completed = ClientLogs()
        let request = ACPRequestPermissionRequest(
            sessionID: "session",
            toolCall: ACPToolCallUpdate(toolCallID: "tool"),
            options: [
                ACPPermissionOption(
                    optionID: "allow",
                    name: "Allow",
                    kind: .allowOnce
                )
            ]
        )

        await coordinator.beginPrompt(sessionID: request.sessionID)
        let responseTask = Task {
            try await coordinator.request(request) { _ in
                await started.record("started")
                await gate.wait()
                return ACPRequestPermissionResponse(
                    outcome: .selected(optionID: "allow")
                )
            }
        }
        #expect(await eventually { await started.messages == ["started"] })

        let observer = Task {
            let response = try await responseTask.value
            await completed.record(response.outcome == .cancelled ? "cancelled" : "selected")
        }
        await coordinator.cancel(sessionID: request.sessionID)
        let completedBeforeHandlerReturned = await eventually(for: .seconds(1)) {
            await completed.messages == ["cancelled"]
        }

        await gate.open()
        try await observer.value
        #expect(completedBeforeHandlerReturned)
        #expect(await completed.messages == ["cancelled"])
    }
}
