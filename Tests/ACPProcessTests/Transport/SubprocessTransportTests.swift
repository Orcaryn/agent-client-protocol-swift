import ACPTestSupport
import Darwin
import Foundation
import Testing

@testable import ACP
import ACPModel
@testable import ACPProcess

struct ACPSubprocessTransportTests {
    @Test func rejectsIncompleteWrites() {
        #expect(
            throws: ACPProcessWriteError.incompleteWrite(expected: 8, actual: 3)
        ) {
            try requireCompleteACPProcessWrite(3, expected: 8)
        }
    }

    @Test func closedAgentStdinFailsSendWithoutTerminatingTheClient() async throws {
        let events = TransportEvents()
        let script = """
            import os, sys, time
            os.close(0)
            sys.stderr.write('ready\\n')
            sys.stderr.flush()
            time.sleep(30)
            """
        let transport = ACPSubprocessTransport(
            launch: ACPProcessLaunch(
                executableURL: URL(fileURLWithPath: "/usr/bin/python3"),
                arguments: ["-c", script]
            )
        )

        try await transport.start(
            onMessage: { _ in },
            onLog: { await events.record(log: $0) },
            onTermination: { await events.record($0) }
        )
        #expect(await eventually { await events.logs == ["ready"] })

        await #expect(throws: (any Error).self) {
            try await transport.send(.notification(method: "sent", params: nil))
        }

        await transport.terminate()
        #expect(await eventually { await events.terminations == [.terminated] })
    }

    @Test func terminationBypassesABlockedStdinWrite() async throws {
        let events = TransportEvents()
        let rawMessages = RawMessageEvents()
        let script = """
            import signal, sys, time
            signal.signal(signal.SIGTERM, signal.SIG_IGN)
            sys.stderr.write('ready\\n')
            sys.stderr.flush()
            time.sleep(2)
            """
        let transport = ACPSubprocessTransport(
            launch: ACPProcessLaunch(
                executableURL: URL(fileURLWithPath: "/usr/bin/python3"),
                arguments: ["-c", script]
            ),
            terminationGracePeriod: .milliseconds(20),
            onRawMessage: { direction, data in
                await rawMessages.record(direction: direction, data: data)
            }
        )

        try await transport.start(
            onMessage: { _ in },
            onLog: { await events.record(log: $0) },
            onTermination: { await events.record($0) }
        )
        #expect(await eventually { await events.logs == ["ready"] })

        let send = Task {
            try await transport.send(
                .notification(
                    method: "large",
                    params: .string(String(repeating: "x", count: 2 * 1024 * 1024))
                )
            )
        }
        #expect(await eventually { await rawMessages.messages.count == 1 })
        try await Task.sleep(for: .milliseconds(50))

        let clock = ContinuousClock()
        let started = clock.now
        await transport.terminate()
        let elapsed = started.duration(to: clock.now)

        #expect(elapsed < .seconds(1))
        await #expect(throws: (any Error).self) {
            try await send.value
        }
        #expect(await eventually { await events.terminations == [.terminated] })
    }

    @Test func reportsRawMessagesInBothDirections() async throws {
        let rawMessages = RawMessageEvents()
        let script = """
            import sys
            sys.stdin.readline()
            sys.stdout.write('{"jsonrpc":"2.0","method":"received"}\\n')
            sys.stdout.flush()
            """
        let transport = ACPSubprocessTransport(
            launch: ACPProcessLaunch(
                executableURL: URL(fileURLWithPath: "/usr/bin/python3"),
                arguments: ["-c", script]
            ),
            onRawMessage: { direction, data in
                await rawMessages.record(direction: direction, data: data)
            }
        )

        try await transport.start(
            onMessage: { _ in },
            onLog: { _ in },
            onTermination: { _ in }
        )
        try await transport.send(.notification(method: "sent", params: nil))

        #expect(await eventually { await rawMessages.messages.count == 2 })
        let messages = await rawMessages.messages
        #expect(messages.map(\.direction) == [.clientToAgent, .agentToClient])
        #expect(
            try messages.map { try JSONDecoder().decode(ACPJSONRPCMessage.self, from: $0.data) }
                == [
                    .notification(method: "sent", params: nil),
                    .notification(method: "received", params: nil),
                ]
        )
    }

    @Test func drainsValidFinalOutputAndStderrBeforeReportingExit() async throws {
        let events = TransportEvents()
        let script = """
            import sys
            sys.stdout.write('{"jsonrpc":"2.0","method":"final"}')
            sys.stdout.flush()
            sys.stderr.write('last')
            sys.stderr.flush()
            sys.exit(4)
            """
        let transport = ACPSubprocessTransport(
            launch: ACPProcessLaunch(
                executableURL: URL(fileURLWithPath: "/usr/bin/python3"),
                arguments: ["-c", script]
            ))

        try await transport.start(
            onMessage: { await events.record($0) },
            onLog: { await events.record(log: $0) },
            onTermination: { await events.record($0) }
        )

        #expect(await eventually { await events.terminations == [.processExited(4)] })
        #expect(await events.messages == [.notification(method: "final", params: nil)])
        #expect(await events.logs == ["last"])
    }

    @Test func terminateWaitsForTheChildToExit() async throws {
        let events = TransportEvents()
        let script = """
            import signal, sys, time
            signal.signal(signal.SIGTERM, signal.SIG_IGN)
            sys.stderr.write('ready\\n')
            sys.stderr.flush()
            time.sleep(30)
            """
        let transport = ACPSubprocessTransport(
            launch: ACPProcessLaunch(
                executableURL: URL(fileURLWithPath: "/usr/bin/python3"),
                arguments: ["-c", script]
            ),
            terminationGracePeriod: .milliseconds(100)
        )
        try await transport.start(
            onMessage: { _ in },
            onLog: { await events.record(log: $0) },
            onTermination: { await events.record($0) }
        )
        #expect(await eventually { await events.logs == ["ready"] })

        let clock = ContinuousClock()
        let start = clock.now
        await transport.terminate()
        let elapsed = start.duration(to: clock.now)

        #expect(elapsed >= .milliseconds(80))
        #expect(await events.terminations == [.terminated])
    }

    @Test func terminateKillsTheEntireAgentProcessTree() async throws {
        let events = TransportEvents()
        let script = """
            import signal, subprocess, sys, time
            signal.signal(signal.SIGTERM, signal.SIG_IGN)
            child = subprocess.Popen([
                sys.executable,
                '-c',
                'import signal,time; signal.signal(signal.SIGTERM, signal.SIG_IGN); time.sleep(30)'
            ])
            sys.stderr.write(f'{child.pid}\\n')
            sys.stderr.flush()
            time.sleep(30)
            """
        let transport = ACPSubprocessTransport(
            launch: ACPProcessLaunch(
                executableURL: URL(fileURLWithPath: "/usr/bin/python3"),
                arguments: ["-c", script]
            ),
            terminationGracePeriod: .milliseconds(100)
        )
        try await transport.start(
            onMessage: { _ in },
            onLog: { await events.record(log: $0) },
            onTermination: { await events.record($0) }
        )
        #expect(await eventually { await events.logs.count == 1 })
        let childPID = try #require(Int32(await events.logs.first!))
        defer {
            Darwin.kill(childPID, SIGKILL)
        }

        await transport.terminate()

        #expect(
            await eventually {
                Darwin.kill(childPID, 0) == -1 && errno == ESRCH
            }
        )
        #expect(await events.terminations == [.terminated])
    }

    @Test func invalidAgentStdoutTerminatesTheProcess() async throws {
        let events = TransportEvents()
        let script = """
            import sys, time
            sys.stdout.write('not-json\\n42\\n')
            sys.stdout.write('{"jsonrpc":"2.0","method":"final"}')
            sys.stdout.flush()
            sys.stderr.write('part')
            sys.stderr.flush()
            time.sleep(0.05)
            sys.stderr.write('ial\\nlast')
            sys.stderr.flush()
            sys.exit(4)
            """
        let transport = ACPSubprocessTransport(
            launch: ACPProcessLaunch(
                executableURL: URL(fileURLWithPath: "/usr/bin/python3"),
                arguments: ["-c", script]
            ))

        try await transport.start(
            onMessage: { await events.record($0) },
            onLog: { await events.record(log: $0) },
            onTermination: { await events.record($0) }
        )

        #expect(
            await eventually(for: .seconds(5)) {
                await events.terminations == [
                    .invalidMessage("Agent stdout contained an invalid ACP message")
                ]
            })
        #expect(await events.messages.isEmpty)
    }
}
