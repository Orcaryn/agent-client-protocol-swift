import Foundation

public struct ACPNewSessionRequest: Codable, Equatable, Sendable {
    public let cwd: String
    @ACPLossyOptionalArray public var additionalDirectories: [String]?
    @ACPRequiredLossyArray public var mcpServers: [ACPMCPServer]
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(
        cwd: String,
        additionalDirectories: [String]? = nil,
        mcpServers: [ACPMCPServer] = [],
        _meta: ACPMeta? = nil
    ) {
        self.cwd = cwd
        self.additionalDirectories = additionalDirectories
        self.mcpServers = mcpServers
        self._meta = _meta
    }
}

public struct ACPNewSessionResponse: Codable, Equatable, Sendable {
    public let sessionID: String
    @ACPDefaultOnError public var modes: ACPSessionModeState?
    @ACPLossyOptionalArray public var configOptions: [ACPSessionConfigOption]?
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(
        sessionID: String,
        modes: ACPSessionModeState? = nil,
        configOptions: [ACPSessionConfigOption]? = nil,
        _meta: ACPMeta? = nil
    ) {
        self.sessionID = sessionID
        self.modes = modes
        self.configOptions = configOptions
        self._meta = _meta
    }

    private enum CodingKeys: String, CodingKey {
        case sessionID = "sessionId"
        case modes, configOptions, _meta
    }
}

public struct ACPLoadSessionRequest: Codable, Equatable, Sendable {
    @ACPRequiredLossyArray public var mcpServers: [ACPMCPServer]
    public let cwd: String
    @ACPLossyOptionalArray public var additionalDirectories: [String]?
    public let sessionID: String
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(
        sessionID: String,
        cwd: String,
        additionalDirectories: [String]? = nil,
        mcpServers: [ACPMCPServer] = [],
        _meta: ACPMeta? = nil
    ) {
        self.mcpServers = mcpServers
        self.cwd = cwd
        self.additionalDirectories = additionalDirectories
        self.sessionID = sessionID
        self._meta = _meta
    }

    private enum CodingKeys: String, CodingKey {
        case mcpServers, cwd, additionalDirectories
        case sessionID = "sessionId"
        case _meta
    }
}

public struct ACPLoadSessionResponse: Codable, Equatable, Sendable {
    @ACPDefaultOnError public var modes: ACPSessionModeState?
    @ACPLossyOptionalArray public var configOptions: [ACPSessionConfigOption]?
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(
        modes: ACPSessionModeState? = nil,
        configOptions: [ACPSessionConfigOption]? = nil,
        _meta: ACPMeta? = nil
    ) {
        self.modes = modes
        self.configOptions = configOptions
        self._meta = _meta
    }
}

public struct ACPResumeSessionRequest: Codable, Equatable, Sendable {
    public let sessionID: String
    public let cwd: String
    @ACPLossyOptionalArray public var additionalDirectories: [String]?
    @ACPLossyOptionalArray public var mcpServers: [ACPMCPServer]?
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(
        sessionID: String,
        cwd: String,
        additionalDirectories: [String]? = nil,
        mcpServers: [ACPMCPServer]? = nil,
        _meta: ACPMeta? = nil
    ) {
        self.sessionID = sessionID
        self.cwd = cwd
        self.additionalDirectories = additionalDirectories
        self.mcpServers = mcpServers
        self._meta = _meta
    }

    private enum CodingKeys: String, CodingKey {
        case sessionID = "sessionId"
        case cwd, additionalDirectories, mcpServers, _meta
    }
}

public typealias ACPResumeSessionResponse = ACPLoadSessionResponse

public struct ACPSessionInfo: Codable, Equatable, Sendable {
    public let sessionID: String
    public let cwd: String
    @ACPLossyOptionalArray public var additionalDirectories: [String]?
    @ACPDefaultOnError public var title: String?
    @ACPDefaultOnError public var updatedAt: String?
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(
        sessionID: String,
        cwd: String,
        additionalDirectories: [String]? = nil,
        title: String? = nil,
        updatedAt: String? = nil,
        _meta: ACPMeta? = nil
    ) {
        self.sessionID = sessionID
        self.cwd = cwd
        self.additionalDirectories = additionalDirectories
        self.title = title
        self.updatedAt = updatedAt
        self._meta = _meta
    }

    private enum CodingKeys: String, CodingKey {
        case sessionID = "sessionId"
        case cwd, additionalDirectories, title, updatedAt, _meta
    }
}

public struct ACPListSessionsRequest: Codable, Equatable, Sendable {
    @ACPDefaultOnError public var cwd: String?
    @ACPDefaultOnError public var cursor: String?
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(cwd: String? = nil, cursor: String? = nil, _meta: ACPMeta? = nil) {
        self.cwd = cwd
        self.cursor = cursor
        self._meta = _meta
    }
}

public struct ACPListSessionsResponse: Codable, Equatable, Sendable {
    @ACPRequiredLossyArray public var sessions: [ACPSessionInfo]
    @ACPDefaultOnError public var nextCursor: String?
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(sessions: [ACPSessionInfo], nextCursor: String? = nil, _meta: ACPMeta? = nil) {
        self.sessions = sessions
        self.nextCursor = nextCursor
        self._meta = _meta
    }
}

public struct ACPSessionIDRequest: Codable, Equatable, Sendable {
    public let sessionID: String
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(sessionID: String, _meta: ACPMeta? = nil) {
        self.sessionID = sessionID
        self._meta = _meta
    }

    private enum CodingKeys: String, CodingKey {
        case sessionID = "sessionId"
        case _meta
    }
}

public typealias ACPDeleteSessionRequest = ACPSessionIDRequest
public typealias ACPDeleteSessionResponse = ACPEmptyResponse
public typealias ACPCloseSessionRequest = ACPSessionIDRequest
public typealias ACPCloseSessionResponse = ACPEmptyResponse
