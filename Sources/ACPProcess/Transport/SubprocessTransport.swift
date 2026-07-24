import ACP
import ACPModel
import Foundation

struct ACPProcessWrite: Sendable {
    let data: Data
    let continuation: CheckedContinuation<Void, any Error>
}

public actor ACPSubprocessTransport: ACPMessageTransport {
    private enum State {
        case idle
        case starting
        case running
        case stopping
        case closed
    }

    private let launch: ACPProcessLaunch
    private let terminationGracePeriod: Duration
    private let onRawMessage: ACPRawMessageHandler?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var state = State.idle
    private var writeContinuation: AsyncStream<ACPProcessWrite>.Continuation?
    // Kept separate from writes so teardown can interrupt a blocked stdin write.
    private var terminationContinuation: AsyncStream<Void>.Continuation?
    private var startContinuation: CheckedContinuation<Void, any Error>?
    private var outputBuffer: ACPLineBuffer
    private var errorBuffer: ACPLineBuffer
    private var requestedTermination: ACPTransportTermination?
    private var processExitWaiters: [CheckedContinuation<Void, Never>] = []
    private var onMessage: ACPMessageHandler?
    private var onLog: ACPLogHandler?
    private var onTermination: ACPTerminationHandler?

    public init(
        launch: ACPProcessLaunch,
        maximumFrameBytes: Int = ACPTransportDefaults.maximumFrameBytes,
        terminationGracePeriod: Duration = .milliseconds(100),
        onRawMessage: ACPRawMessageHandler? = nil
    ) {
        precondition(terminationGracePeriod >= .zero, "terminationGracePeriod must not be negative")
        self.launch = launch
        self.terminationGracePeriod = terminationGracePeriod
        self.onRawMessage = onRawMessage
        outputBuffer = ACPLineBuffer(maximumFrameBytes: maximumFrameBytes)
        errorBuffer = ACPLineBuffer(maximumFrameBytes: maximumFrameBytes)
    }

    public func start(
        onMessage: @escaping ACPMessageHandler,
        onLog: @escaping ACPLogHandler,
        onTermination: @escaping ACPTerminationHandler
    ) async throws {
        guard case .idle = state else {
            throw ACPTransportError.alreadyStarted
        }

        state = .starting
        self.onMessage = onMessage
        self.onLog = onLog
        self.onTermination = onTermination

        let (writes, writeContinuation) = AsyncStream<ACPProcessWrite>.makeStream()
        self.writeContinuation = writeContinuation
        let (terminationRequests, terminationContinuation) = AsyncStream<Void>.makeStream()
        self.terminationContinuation = terminationContinuation

        try await withCheckedThrowingContinuation { continuation in
            startContinuation = continuation
            Task { [self, launch] in
                do {
                    let status = try await runACPProcess(
                        launch: launch,
                        writes: writes,
                        terminationRequests: terminationRequests,
                        terminationGracePeriod: terminationGracePeriod,
                        onStart: processStarted,
                        onOutput: consumeOutput,
                        onError: consumeError,
                        onStreamsClosed: processStreamsClosed
                    )
                    await processCompleted(status: status)
                } catch {
                    await processFailed(error)
                }
            }
        }
    }

    public func send(_ message: ACPJSONRPCMessage) async throws {
        switch state {
        case .idle, .starting:
            throw ACPTransportError.notStarted
        case .stopping, .closed:
            throw ACPTransportError.closed
        case .running:
            break
        }

        guard let writeContinuation else {
            throw ACPTransportError.closed
        }

        var data = try encoder.encode(message)
        await onRawMessage?(.clientToAgent, data)
        data.append(0x0A)
        try await withCheckedThrowingContinuation { continuation in
            switch writeContinuation.yield(ACPProcessWrite(data: data, continuation: continuation)) {
            case .enqueued:
                break
            case .dropped, .terminated:
                continuation.resume(throwing: ACPTransportError.closed)
            @unknown default:
                continuation.resume(throwing: ACPTransportError.closed)
            }
        }
    }

    public func terminate() async {
        switch state {
        case .idle, .closed:
            return
        case .stopping:
            await waitForProcessExit()
        case .starting, .running:
            requestProcessStop(reason: .terminated)
            await waitForProcessExit()
        }
    }

    private func processStarted() {
        guard case .starting = state else {
            return
        }

        state = .running
        startContinuation?.resume()
        startContinuation = nil
    }

    private func processFailed(_ error: any Error) async {
        switch state {
        case .starting:
            state = .idle
            startContinuation?.resume(throwing: error)
            startContinuation = nil
            finishProcessInputStreams()
        case .running, .stopping:
            await finish(requestedTermination ?? .terminated)
        case .idle, .closed:
            break
        }
    }

    private func consumeOutput(_ data: Data) async {
        guard case .running = state else { return }
        let result = outputBuffer.append(data)
        for line in result.lines {
            guard await consumeOutputLine(line) else { return }
        }
        if result.exceededMaximum {
            requestProcessStop(reason: .invalidMessage("ACP frame exceeded the configured maximum size"))
        }
    }

    private func consumeError(_ data: Data) async {
        let result = errorBuffer.append(data)
        for line in result.lines {
            await onLog?(String(decoding: line, as: UTF8.self))
        }
        if result.exceededMaximum {
            await onLog?("Agent stderr line exceeded the configured maximum size")
        }
    }

    private func processStreamsClosed() async {
        if case .running = state,
            let line = outputBuffer.takeRemainder(),
            !line.isEmpty,
            !(await consumeOutputLine(line))
        {
            return
        }
        if let line = errorBuffer.takeRemainder() {
            await onLog?(String(decoding: line, as: UTF8.self))
        }
        finishProcessInputStreams()
    }

    private func consumeOutputLine(_ line: Data) async -> Bool {
        guard !ACPLineBuffer.isBlank(line) else { return true }
        guard let message = try? decoder.decode(ACPJSONRPCMessage.self, from: line) else {
            requestProcessStop(reason: .invalidMessage("Agent stdout contained an invalid ACP message"))
            return false
        }
        await onRawMessage?(.agentToClient, line)
        await onMessage?(message)
        return true
    }

    private func requestProcessStop(reason: ACPTransportTermination) {
        switch state {
        case .starting, .running:
            break
        case .idle, .stopping, .closed:
            return
        }
        state = .stopping
        requestedTermination = reason
        terminationContinuation?.yield()
        finishProcessInputStreams()
    }

    private func processCompleted(status: Int32) async {
        await finish(requestedTermination ?? .processExited(status))
    }

    private func waitForProcessExit() async {
        if case .closed = state {
            return
        }
        await withCheckedContinuation { continuation in
            processExitWaiters.append(continuation)
        }
    }

    private func finish(_ termination: ACPTransportTermination) async {
        if case .closed = state {
            return
        }

        state = .closed
        startContinuation?.resume(throwing: ACPTransportError.closed)
        startContinuation = nil
        finishProcessInputStreams()
        let waiters = processExitWaiters
        processExitWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
        await onTermination?(termination)
    }

    private func finishProcessInputStreams() {
        writeContinuation?.finish()
        writeContinuation = nil
        terminationContinuation?.finish()
        terminationContinuation = nil
    }
}
