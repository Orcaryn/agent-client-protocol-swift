import Foundation

public enum ACPStopReason: String, Codable, Equatable, Sendable {
    case endTurn = "end_turn"
    case maxTokens = "max_tokens"
    case maxTurnRequests = "max_turn_requests"
    case refusal
    case cancelled
}

public struct ACPPromptRequest: Codable, Equatable, Sendable {
    public let sessionID: String
    public let prompt: [ACPContentBlock]
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(sessionID: String, prompt: [ACPContentBlock], _meta: ACPMeta? = nil) {
        self.sessionID = sessionID
        self.prompt = prompt
        self._meta = _meta
    }

    private enum CodingKeys: String, CodingKey {
        case sessionID = "sessionId"
        case prompt, _meta
    }
}

public struct ACPPromptResponse: Codable, Equatable, Sendable {
    public let stopReason: ACPStopReason
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(stopReason: ACPStopReason, _meta: ACPMeta? = nil) {
        self.stopReason = stopReason
        self._meta = _meta
    }
}

public struct ACPCancelSessionNotification: Codable, Equatable, Sendable {
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
