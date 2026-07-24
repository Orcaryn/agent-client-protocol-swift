import ACPTestSupport
import Darwin
import Foundation
import Testing

@testable import ACP
import ACPModel
import ACPProcess

extension ACPAgentClientProcessTests {
    @Test func protocolVersionMismatchClosesConnectionAndDoesNotInitializeClient() async throws {
        let client = ACPAgentClient(
            launch: makeLaunch(environment: ["ACP_TEST_PROTOCOL_VERSION": "2"])
        )

        await #expect(
            throws: ACPAgentClientError.protocolVersionMismatch(expected: 1, received: 2)
        ) {
            try await client.connect()
        }
        #expect(await client.initialization == nil)

        await #expect(throws: ACPAgentClientError.self) {
            try await client.newSession(cwd: "/tmp")
        }
    }
    @Test func initializationErrorClosesConnectionAndTerminatesAgent() async throws {
        let events = TransportEvents()
        let client = ACPAgentClient(
            launch: makeLaunch(environment: ["ACP_TEST_INITIALIZE_ERROR": "1"]),
            callbacks: ACPAgentClientCallbacks(
                lifecycle: ACPClientLifecycleCallbacks(
                    termination: { termination in await events.record(termination) }
                )
            )
        )

        await #expect(throws: ACPJSONRPCError.self) {
            try await client.connect()
        }
        #expect(await client.initialization == nil)
        #expect(await events.terminations == [.terminated])
    }
    @Test func malformedClientRequestReturnsInvalidParamsWithoutCallingCallback() async throws {
        let callbackCalls = ClientMethodCalls()
        let client = ACPAgentClient(
            launch: makeLaunch(environment: ["ACP_TEST_MALFORMED_CLIENT_REQUEST": "1"]),
            clientCapabilities: ACPClientCapabilities(
                fs: ACPFileSystemCapabilities(readTextFile: true)
            ),
            callbacks: ACPAgentClientCallbacks(
                fileSystem: ACPClientFileSystemCallbacks(
                    readTextFile: { _ in
                        await callbackCalls.record("unexpected")
                        return ACPReadTextFileResponse(content: "unexpected")
                    }
                )
            )
        )

        let response = try await client.connect()
        #expect(response.protocolVersion == 1)
        #expect(await callbackCalls.methods.isEmpty)
        await client.shutdown()
    }

    func makeClient(callbacks: ACPAgentClientCallbacks) -> ACPAgentClient {
        return ACPAgentClient(
            launch: makeLaunch(),
            clientCapabilities: ACPClientCapabilities(
                fs: ACPFileSystemCapabilities(
                    readTextFile: true,
                    writeTextFile: true
                ),
                terminal: true,
                session: ACPClientSessionCapabilities(
                    configOptions: ACPSessionConfigOptionsCapabilities(
                        boolean: ACPBooleanConfigOptionCapabilities()
                    )
                )
            ),
            clientInfo: ACPImplementationInfo(
                name: "swift-acp-tests",
                title: "Swift ACP Tests",
                version: "1.0.0"
            ),
            callbacks: callbacks
        )
    }

    func connectAndShutdown(
        probe: ClientLifetimeProbe
    ) async throws -> AsyncStream<ACPAgentClientEvent> {
        let callbackToken = ClientLifetimeToken()
        let client = ACPAgentClient(
            launch: makeLaunch(),
            callbacks: ACPAgentClientCallbacks(
                session: ACPClientSessionCallbacks(
                    update: { [callbackToken] _ in callbackToken.touch() }
                )
            )
        )
        await probe.track(client: client, callbackToken: callbackToken)

        let events = await client.events()
        _ = try await client.connect()
        await client.shutdown()
        return events
    }

    func connectAndShutdown(recordingPIDAt url: URL) async throws -> Int32 {
        let client = ACPAgentClient(
            launch: makeLaunch(environment: ["ACP_TEST_PID_PATH": url.path])
        )
        do {
            _ = try await client.connect()
            let pid = try #require(Int32(String(contentsOf: url, encoding: .utf8)))
            await client.shutdown()
            return pid
        } catch {
            await client.shutdown()
            throw error
        }
    }

    func processHasExited(_ pid: Int32) -> Bool {
        Darwin.kill(pid, 0) == -1 && errno == ESRCH
    }

    func makeLaunch(environment: [String: String] = [:]) -> ACPProcessLaunch {
        let fixture = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/fake_acp_agent.py")

        return ACPProcessLaunch(
            executableURL: URL(fileURLWithPath: "/usr/bin/python3"),
            arguments: [fixture.path],
            environment: environment
        )
    }
}
