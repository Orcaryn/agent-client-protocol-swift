import Foundation
import Testing

@testable import ACP
import ACPModel
import ACPProcess

private actor ConnectionEvents {
    private(set) var notifications: [String] = []
    private(set) var requests: [String] = []
    private(set) var logs: [String] = []

    func recordNotification(_ method: String) {
        notifications.append(method)
    }

    func recordRequest(_ method: String) {
        requests.append(method)
    }

    func recordLog(_ line: String) {
        logs.append(line)
    }
}

struct ACPProcessConnectionIntegrationTests {
    @Test func handlesFullDuplexRequestsAndNotificationsWhileAwaitingResponse() async throws {
        let events = ConnectionEvents()
        let connection = makeConnection(
            handlers: ACPConnectionHandlers(
                onNotification: { _, method, _ in
                    await events.recordNotification(method)
                },
                onRequest: { _, method, _ in
                    await events.recordRequest(method)
                    return try ACPValue.encode(
                        ACPRequestPermissionResponse(outcome: .selected(optionID: "allow-once"))
                    )
                },
                onLog: { line in
                    await events.recordLog(line)
                }
            )
        )

        try await connection.start()
        let response: ACPInitializeResponse = try await connection.request(
            method: ACPProtocol.Method.initialize,
            params: ACPInitializeRequest(clientCapabilities: ACPClientCapabilities())
        )

        #expect(response.protocolVersion == 1)
        #expect(response.agentCapabilities.loadSession == true)
        #expect(await events.notifications == [ACPProtocol.Method.sessionUpdate])
        #expect(await events.requests == [ACPProtocol.Method.sessionRequestPermission])

        await connection.close()
    }

    @Test func correlatesConcurrentResponsesByRequestID() async throws {
        struct Echo: Codable, Equatable {
            let value: String
        }

        let connection = makeConnection()
        try await connection.start()

        async let first: Echo = connection.request(method: "echo", params: Echo(value: "first"))
        async let second: Echo = connection.request(method: "echo", params: Echo(value: "second"))
        let responses = try await [first, second]

        #expect(responses == [Echo(value: "first"), Echo(value: "second")])
        await connection.close()
    }

    @Test func processExitFailsPendingRequests() async throws {
        let connection = makeConnection()
        try await connection.start()

        do {
            let _: ACPEmptyResponse = try await connection.request(
                method: "exit",
                params: ACPEmptyResponse()
            )
            Issue.record("Expected the request to fail when the process exited")
        } catch let termination as ACPTransportTermination {
            #expect(termination == .processExited(7))
        }
    }

    @Test func blankStandardOutputLineIsIgnoredAndNextMessageIsProcessed() async throws {
        let connection = makeConnection()
        try await connection.start()

        let response: ACPEmptyResponse = try await connection.request(
            method: "blank_line",
            params: ACPEmptyResponse()
        )
        #expect(response == ACPEmptyResponse())
        await connection.close()
    }

    private func makeConnection(handlers: ACPConnectionHandlers = ACPConnectionHandlers()) -> ACPConnection {
        let fixture = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/fake_acp_agent.py")

        return ACPConnection(
            launch: ACPProcessLaunch(
                executableURL: URL(fileURLWithPath: "/usr/bin/python3"),
                arguments: [fixture.path],
                environment: ["ACP_TEST_FULL_DUPLEX_INITIALIZE": "1"]
            ),
            handlers: handlers
        )
    }
}
