import Foundation

public struct ACPCreateTerminalRequest: Codable, Equatable, Sendable {
    public let sessionID: String
    public let command: String
    @ACPLossyOptionalArray public var args: [String]?
    @ACPLossyOptionalArray public var env: [ACPEnvironmentVariable]?
    @ACPDefaultOnError public var cwd: String?
    @ACPDefaultOnError public var outputByteLimit: UInt64?
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(
        sessionID: String,
        command: String,
        args: [String]? = nil,
        env: [ACPEnvironmentVariable]? = nil,
        cwd: String? = nil,
        outputByteLimit: UInt64? = nil,
        _meta: ACPMeta? = nil
    ) {
        self.sessionID = sessionID
        self.command = command
        self.args = args
        self.env = env
        self.cwd = cwd
        self.outputByteLimit = outputByteLimit
        self._meta = _meta
    }

    private enum CodingKeys: String, CodingKey {
        case sessionID = "sessionId"
        case command, args, env, cwd, outputByteLimit, _meta
    }
}

public struct ACPCreateTerminalResponse: Codable, Equatable, Sendable {
    public let terminalID: String
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(terminalID: String, _meta: ACPMeta? = nil) {
        self.terminalID = terminalID
        self._meta = _meta
    }

    private enum CodingKeys: String, CodingKey {
        case terminalID = "terminalId"
        case _meta
    }
}

public struct ACPTerminalRequest: Codable, Equatable, Sendable {
    public let sessionID: String
    public let terminalID: String
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(sessionID: String, terminalID: String, _meta: ACPMeta? = nil) {
        self.sessionID = sessionID
        self.terminalID = terminalID
        self._meta = _meta
    }

    private enum CodingKeys: String, CodingKey {
        case sessionID = "sessionId"
        case terminalID = "terminalId"
        case _meta
    }
}

public typealias ACPTerminalOutputRequest = ACPTerminalRequest
public typealias ACPReleaseTerminalRequest = ACPTerminalRequest
public typealias ACPWaitForTerminalExitRequest = ACPTerminalRequest
public typealias ACPKillTerminalRequest = ACPTerminalRequest
public typealias ACPReleaseTerminalResponse = ACPEmptyResponse
public typealias ACPKillTerminalResponse = ACPEmptyResponse

public struct ACPTerminalExitStatus: Codable, Equatable, Sendable {
    @ACPDefaultOnError public var exitCode: UInt32?
    @ACPDefaultOnError public var signal: String?
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(exitCode: UInt32? = nil, signal: String? = nil, _meta: ACPMeta? = nil) {
        self.exitCode = exitCode
        self.signal = signal
        self._meta = _meta
    }
}

public struct ACPTerminalOutputResponse: Codable, Equatable, Sendable {
    public let output: String
    public let truncated: Bool
    @ACPDefaultOnError public var exitStatus: ACPTerminalExitStatus?
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(
        output: String,
        truncated: Bool,
        exitStatus: ACPTerminalExitStatus? = nil,
        _meta: ACPMeta? = nil
    ) {
        self.output = output
        self.truncated = truncated
        self.exitStatus = exitStatus
        self._meta = _meta
    }
}

public struct ACPWaitForTerminalExitResponse: Codable, Equatable, Sendable {
    @ACPDefaultOnError public var exitCode: UInt32?
    @ACPDefaultOnError public var signal: String?
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(exitCode: UInt32? = nil, signal: String? = nil, _meta: ACPMeta? = nil) {
        self.exitCode = exitCode
        self.signal = signal
        self._meta = _meta
    }
}
