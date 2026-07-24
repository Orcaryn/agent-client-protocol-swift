import Foundation

public struct ACPReadTextFileRequest: Codable, Equatable, Sendable {
    public let sessionID: String
    public let path: String
    @ACPDefaultOnError public var line: UInt32?
    @ACPDefaultOnError public var limit: UInt32?
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(
        sessionID: String,
        path: String,
        line: UInt32? = nil,
        limit: UInt32? = nil,
        _meta: ACPMeta? = nil
    ) {
        self.sessionID = sessionID
        self.path = path
        self.line = line
        self.limit = limit
        self._meta = _meta
    }

    private enum CodingKeys: String, CodingKey {
        case sessionID = "sessionId"
        case path, line, limit, _meta
    }
}

public struct ACPReadTextFileResponse: Codable, Equatable, Sendable {
    public let content: String
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(content: String, _meta: ACPMeta? = nil) {
        self.content = content
        self._meta = _meta
    }
}

public struct ACPWriteTextFileRequest: Codable, Equatable, Sendable {
    public let sessionID: String
    public let path: String
    public let content: String
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(sessionID: String, path: String, content: String, _meta: ACPMeta? = nil) {
        self.sessionID = sessionID
        self.path = path
        self.content = content
        self._meta = _meta
    }

    private enum CodingKeys: String, CodingKey {
        case sessionID = "sessionId"
        case path, content, _meta
    }
}

public typealias ACPWriteTextFileResponse = ACPEmptyResponse
