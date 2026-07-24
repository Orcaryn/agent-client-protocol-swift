import Foundation
import Subprocess
import System

#if canImport(Darwin)
    import Darwin
#endif

enum ACPProcessWriteError: Error, Equatable {
    case incompleteWrite(expected: Int, actual: Int)
}

func requireCompleteACPProcessWrite(_ actual: Int, expected: Int) throws {
    guard actual == expected else {
        throw ACPProcessWriteError.incompleteWrite(expected: expected, actual: actual)
    }
}

#if canImport(Darwin)
    /// swift-subprocess 0.5.0 writes directly to a pipe and does not suppress
    /// SIGPIPE. Ignoring it once, when process transport is first used, converts a
    /// closed agent stdin into EPIPE instead of terminating the embedding process.
    private let ignoreSIGPIPEForACPProcesses: Void = {
        _ = Darwin.signal(SIGPIPE, SIG_IGN)
    }()
#endif

func runACPProcess(
    launch: ACPProcessLaunch,
    writes: AsyncStream<ACPProcessWrite>,
    terminationRequests: AsyncStream<Void>,
    terminationGracePeriod: Duration,
    onStart: @escaping @Sendable () async -> Void,
    onOutput: @escaping @Sendable (Data) async -> Void,
    onError: @escaping @Sendable (Data) async -> Void,
    onStreamsClosed: @escaping @Sendable () async -> Void
) async throws -> Int32 {
    #if canImport(Darwin)
        _ = ignoreSIGPIPEForACPProcesses
    #endif

    var platformOptions = PlatformOptions()
    platformOptions.createSession = true

    let result = try await run(
        .path(FilePath(launch.executableURL.path)),
        arguments: Arguments(launch.arguments),
        environment: launch.subprocessEnvironment,
        workingDirectory: launch.workingDirectoryURL.map { FilePath($0.path) },
        platformOptions: platformOptions,
        input: .inputWriter,
        output: .sequence,
        error: .sequence
    ) { execution in
        await onStart()

        async let outputDrained: Void = drain(execution.standardOutput, into: onOutput)
        async let errorDrained: Void = drain(execution.standardError, into: onError)
        async let writesProcessed: Void = processWrites(
            writes,
            using: execution
        )
        async let terminationProcessed: Void = processTerminationRequests(
            terminationRequests,
            using: execution,
            terminationGracePeriod: terminationGracePeriod
        )

        _ = await (outputDrained, errorDrained)
        await onStreamsClosed()
        _ = await (writesProcessed, terminationProcessed)
    }

    return result.terminationStatus.acpExitStatus
}

private func drain(
    _ stream: SubprocessOutputSequence,
    into handler: @escaping @Sendable (Data) async -> Void
) async {
    do {
        for try await buffer in stream {
            await handler(buffer.withUnsafeBytes { Data($0) })
        }
    } catch {
        // Process exit cancels outstanding pipe reads.
    }
}

private func processWrites(
    _ writes: AsyncStream<ACPProcessWrite>,
    using execution: Execution<CustomWriteInput, SequenceOutput, SequenceOutput>
) async {
    for await write in writes {
        do {
            let bytesWritten = try await execution.standardInputWriter.write(write.data)
            try requireCompleteACPProcessWrite(bytesWritten, expected: write.data.count)
            write.continuation.resume()
        } catch {
            write.continuation.resume(throwing: error)
        }
    }
}

private func processTerminationRequests(
    _ terminationRequests: AsyncStream<Void>,
    using execution: Execution<CustomWriteInput, SequenceOutput, SequenceOutput>,
    terminationGracePeriod: Duration
) async {
    for await _ in terminationRequests {
        await execution.teardown(using: [
            .gracefulShutDown(
                toProcessGroup: true,
                allowedDurationToNextStep: terminationGracePeriod
            )
        ])
        return
    }
}

extension ACPProcessLaunch {
    fileprivate var subprocessEnvironment: Environment {
        let overrides = environment.reduce(into: [Environment.Key: String?]()) { result, entry in
            guard let key = Environment.Key(rawValue: entry.key) else { return }
            result[key] = entry.value
        }
        return .inherit.updating(overrides)
    }
}

extension TerminationStatus {
    fileprivate var acpExitStatus: Int32 {
        switch self {
        case .exited(let code), .signaled(let code): Int32(code)
        }
    }
}
