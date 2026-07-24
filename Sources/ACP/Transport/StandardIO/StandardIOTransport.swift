import ACPModel

import Foundation

public actor ACPStandardIOTransport: ACPMessageTransport {
    private let input: FileHandle
    private let output: FileHandle
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var buffer: ACPLineBuffer
    private var continuation: AsyncStream<Data>.Continuation?
    private var readTask: Task<Void, Never>?
    private var didStart = false
    private var didFinish = false
    private var onMessage: ACPMessageHandler?
    private var onTermination: ACPTerminationHandler?

    public init(
        input: FileHandle = .standardInput,
        output: FileHandle = .standardOutput,
        maximumFrameBytes: Int = ACPTransportDefaults.maximumFrameBytes
    ) {
        self.input = input
        self.output = output
        buffer = ACPLineBuffer(maximumFrameBytes: maximumFrameBytes)
    }

    public func start(
        onMessage: @escaping ACPMessageHandler,
        onLog _: @escaping ACPLogHandler,
        onTermination: @escaping ACPTerminationHandler
    ) throws {
        guard !didFinish else { throw ACPTransportError.closed }
        guard !didStart else { throw ACPTransportError.alreadyStarted }

        didStart = true
        self.onMessage = onMessage
        self.onTermination = onTermination

        let (stream, continuation) = AsyncStream<Data>.makeStream()
        self.continuation = continuation
        input.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                continuation.finish()
            } else {
                continuation.yield(data)
            }
        }
        readTask = Task { [weak self] in
            for await data in stream {
                await self?.consume(data)
            }
            await self?.consumeFinalLine()
            await self?.finish(.endOfFile)
        }
    }

    public func send(_ message: ACPJSONRPCMessage) throws {
        guard !didFinish else { throw ACPTransportError.closed }
        guard didStart else { throw ACPTransportError.notStarted }

        var data = try encoder.encode(message)
        data.append(0x0A)
        try output.write(contentsOf: data)
    }

    public func terminate() async {
        await finish(.terminated)
    }

    private func consume(_ data: Data) async {
        guard !didFinish else { return }
        let result = buffer.append(data)
        for line in result.lines {
            await consumeLine(line)
            guard !didFinish else { return }
        }
        if result.exceededMaximum {
            await finish(.invalidMessage("ACP frame exceeded the configured maximum size"))
        }
    }

    private func consumeFinalLine() async {
        if !didFinish, let line = buffer.takeRemainder() {
            await consumeLine(line)
        }
    }

    /// ACP stdio is an NDJSON stream. Invalid input receives the JSON-RPC error
    /// required by the protocol without desynchronizing subsequent lines.
    private func consumeLine(_ line: some DataProtocol) async {
        guard !didFinish else { return }
        let data = Data(line)
        guard !ACPLineBuffer.isBlank(data) else {
            return
        }

        guard let message = try? decoder.decode(ACPJSONRPCMessage.self, from: data) else {
            let error: ACPJSONRPCError
            if (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) == nil {
                error = .parseError
            } else {
                error = .invalidRequest
            }
            try? await send(.error(id: .null, error: error))
            return
        }
        await onMessage?(message)
    }

    private func finish(_ termination: ACPTransportTermination) async {
        if didFinish {
            return
        }

        didFinish = true
        input.readabilityHandler = nil
        continuation?.finish()
        continuation = nil
        readTask?.cancel()
        await onTermination?(termination)
    }
}
