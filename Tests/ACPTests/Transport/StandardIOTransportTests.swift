import ACPTestSupport
import Foundation
import Testing

@testable import ACP
import ACPModel

private struct StandardIOHarness {
    let input = Pipe()
    let output = Pipe()
    let events = TransportEvents()
    let transport: ACPStandardIOTransport

    init(maximumFrameBytes: Int = ACPTransportDefaults.maximumFrameBytes) {
        transport = ACPStandardIOTransport(
            input: input.fileHandleForReading,
            output: output.fileHandleForWriting,
            maximumFrameBytes: maximumFrameBytes
        )
    }

    func start(onMessage: ACPMessageHandler? = nil) async throws {
        try await transport.start(
            onMessage: { message in
                if let onMessage {
                    await onMessage(message)
                } else {
                    await events.record(message)
                }
            },
            onLog: { _ in },
            onTermination: { termination in
                await events.record(termination)
            }
        )
    }

    func write(_ data: Data) throws {
        try input.fileHandleForWriting.write(contentsOf: data)
    }

    func closeInput() throws {
        try input.fileHandleForWriting.close()
    }
}

struct ACPStandardIOTransportTests {
    @Test func terminationBeforeStartPermanentlyClosesTransport() async throws {
        let harness = StandardIOHarness()
        let message = ACPJSONRPCMessage.notification(method: "test", params: nil)

        await harness.transport.terminate()

        await #expect(throws: ACPTransportError.closed) {
            try await harness.start()
        }
        await #expect(throws: ACPTransportError.closed) {
            try await harness.transport.send(message)
        }
        #expect(await harness.events.terminations.isEmpty)
    }

    @Test func rejectsFramesOverConfiguredLimit() async throws {
        let harness = StandardIOHarness(maximumFrameBytes: 32)
        try await harness.start()

        try harness.write(Data(String(repeating: "x", count: 33).utf8))

        #expect(
            await eventually {
                await harness.events.terminations == [
                    .invalidMessage("ACP frame exceeded the configured maximum size")
                ]
            })
    }

    @Test func parsesMultipleMessagesFromOneChunk() async throws {
        let harness = StandardIOHarness()
        try await harness.start()

        try harness.write(
            Data(
                """
                {"jsonrpc":"2.0","method":"first"}\n{"jsonrpc":"2.0","method":"second"}\n
                """.utf8
            ))

        #expect(await eventually { await harness.events.messages.count == 2 })
        #expect(
            await harness.events.messages == [
                .notification(method: "first", params: nil),
                .notification(method: "second", params: nil),
            ])
        await harness.transport.terminate()
    }

    @Test func parsesManyMessagesFromOneChunk() async throws {
        let harness = StandardIOHarness()
        try await harness.start()
        let count = 2_000
        let payload =
            (0..<count)
            .map { #"{"jsonrpc":"2.0","method":"message-\#($0)"}"# }
            .joined(separator: "\n") + "\n"

        try harness.write(Data(payload.utf8))

        #expect(await eventually { await harness.events.messages.count == count })
        #expect(await harness.events.messages.first == .notification(method: "message-0", params: nil))
        #expect(
            await harness.events.messages.last
                == .notification(method: "message-1999", params: nil)
        )
        await harness.transport.terminate()
    }

    @Test func parsesMessageSplitAtEveryByteIncludingInsideUTF8Scalar() async throws {
        let harness = StandardIOHarness()
        try await harness.start()
        let bytes =
            Data(
                #"{"jsonrpc":"2.0","method":"echo","params":{"text":"שלום 👋"}}"#.utf8
            ) + Data([0x0A])

        for byte in bytes {
            try harness.write(Data([byte]))
        }

        #expect(await eventually { await harness.events.messages.count == 1 })
        #expect(
            await harness.events.messages == [
                .notification(
                    method: "echo",
                    params: .object(["text": .string("שלום 👋")])
                )
            ])
        await harness.transport.terminate()
    }

    @Test func parsesLargeMessageAcrossManyChunks() async throws {
        let harness = StandardIOHarness()
        try await harness.start()
        let text = String(repeating: "abcdefghij", count: 30_000)
        let message = ACPJSONRPCMessage.notification(
            method: "large",
            params: .object(["text": .string(text)])
        )
        var encoded = try JSONEncoder().encode(message)
        encoded.append(0x0A)

        for offset in stride(from: 0, to: encoded.count, by: 997) {
            try harness.write(encoded[offset..<min(offset + 997, encoded.count)])
        }

        #expect(await eventually(for: .seconds(5)) { await harness.events.messages.count == 1 })
        #expect(await harness.events.messages == [message])
        await harness.transport.terminate()
    }

    @Test func acceptsCRLFAndFlushesFinalUnterminatedMessageAtEOF() async throws {
        let harness = StandardIOHarness()
        try await harness.start()

        try harness.write(
            Data(
                "{\"jsonrpc\":\"2.0\",\"method\":\"crlf\"}\r\n"
                    .appending("{\"jsonrpc\":\"2.0\",\"method\":\"final\"}")
                    .utf8
            ))
        try harness.closeInput()

        #expect(await eventually { await harness.events.terminations == [.endOfFile] })
        #expect(
            await harness.events.messages == [
                .notification(method: "crlf", params: nil),
                .notification(method: "final", params: nil),
            ])
    }

    @Test func respondsToMalformedAndNonObjectLinesThenContinues() async throws {
        let harness = StandardIOHarness()
        try await harness.start()

        try harness.write(
            Data(
                """

                not-json
                42
                {"jsonrpc":"2.0","method":"valid"}

                """.utf8
            ))

        #expect(await eventually { await harness.events.messages.count == 1 })
        #expect(
            await harness.events.messages == [
                .notification(method: "valid", params: nil)
            ])
        #expect(await harness.events.terminations.isEmpty)
        try harness.output.fileHandleForWriting.close()
        let output = try harness.output.fileHandleForReading.readToEnd() ?? Data()
        let errors = try output.split(separator: 0x0A).map {
            try JSONDecoder().decode(ACPJSONRPCMessage.self, from: $0)
        }
        #expect(
            errors == [
                .error(id: .null, error: .parseError),
                .error(id: .null, error: .invalidRequest),
            ])
        await harness.transport.terminate()
    }

    @Test func enforcesLifecycleAndTerminatesIdempotently() async throws {
        let harness = StandardIOHarness()
        let message = ACPJSONRPCMessage.notification(method: "test", params: nil)

        await #expect(throws: ACPTransportError.notStarted) {
            try await harness.transport.send(message)
        }

        try await harness.start()
        await #expect(throws: ACPTransportError.alreadyStarted) {
            try await harness.start()
        }

        await harness.transport.terminate()
        await harness.transport.terminate()

        #expect(await harness.events.terminations == [.terminated])
        await #expect(throws: ACPTransportError.closed) {
            try await harness.transport.send(message)
        }
    }

    @Test func concurrentSendsWriteCompleteNonInterleavedLines() async throws {
        let harness = StandardIOHarness()
        try await harness.start()
        let count = 100

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<count {
                group.addTask {
                    try await harness.transport.send(
                        .notification(
                            method: "message-\(index)",
                            params: .object(["index": .integer(Int64(index))])
                        ))
                }
            }
            try await group.waitForAll()
        }

        try harness.output.fileHandleForWriting.close()
        let data = try harness.output.fileHandleForReading.readToEnd() ?? Data()
        let lines = data.split(separator: 0x0A)
        let decoded = try lines.map {
            try JSONDecoder().decode(ACPJSONRPCMessage.self, from: $0)
        }

        #expect(decoded.count == count)
        #expect(Set(decoded.compactMap(\.notificationMethod)).count == count)
        await harness.transport.terminate()
    }

    @Test func explicitTerminationStopsBufferedMessageDelivery() async throws {
        let harness = StandardIOHarness()
        let events = harness.events
        let firstMessageReceived = AsyncGate()
        let releaseFirstMessage = AsyncGate()
        try await harness.start { message in
            await events.record(message)
            if message.notificationMethod == "first" {
                await firstMessageReceived.open()
                await releaseFirstMessage.wait()
            }
        }

        try harness.write(
            Data(
                """
                {"jsonrpc":"2.0","method":"first"}
                {"jsonrpc":"2.0","method":"second"}

                """.utf8
            ))

        await firstMessageReceived.wait()
        await harness.transport.terminate()
        await releaseFirstMessage.open()
        try await Task.sleep(for: .milliseconds(50))

        #expect(await events.messages == [.notification(method: "first", params: nil)])
        #expect(await events.terminations == [.terminated])
    }

    @Test func outputWriteFailureIsPropagated() async throws {
        let harness = StandardIOHarness()
        try await harness.start()
        try harness.output.fileHandleForWriting.close()

        await #expect(throws: (any Error).self) {
            try await harness.transport.send(.notification(method: "write", params: nil))
        }
        await harness.transport.terminate()
    }
}

extension ACPJSONRPCMessage {
    fileprivate var notificationMethod: String? {
        guard case .notification(let method, _) = self else {
            return nil
        }
        return method
    }
}
