import Foundation

public enum ACPPermissionOptionKind: String, Codable, Equatable, Sendable {
    case allowOnce = "allow_once"
    case allowAlways = "allow_always"
    case rejectOnce = "reject_once"
    case rejectAlways = "reject_always"
}

public struct ACPPermissionOption: Codable, Equatable, Identifiable, Sendable {
    public var id: String { optionID }

    public let optionID: String
    public let name: String
    public let kind: ACPPermissionOptionKind
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(
        optionID: String,
        name: String,
        kind: ACPPermissionOptionKind,
        _meta: ACPMeta? = nil
    ) {
        self.optionID = optionID
        self.name = name
        self.kind = kind
        self._meta = _meta
    }

    private enum CodingKeys: String, CodingKey {
        case optionID = "optionId"
        case name, kind, _meta
    }
}

public struct ACPRequestPermissionRequest: Codable, Equatable, Sendable {
    public let sessionID: String
    public let toolCall: ACPToolCallUpdate
    public let options: [ACPPermissionOption]
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(
        sessionID: String,
        toolCall: ACPToolCallUpdate,
        options: [ACPPermissionOption],
        _meta: ACPMeta? = nil
    ) {
        self.sessionID = sessionID
        self.toolCall = toolCall
        self.options = options
        self._meta = _meta
    }

    private enum CodingKeys: String, CodingKey {
        case sessionID = "sessionId"
        case toolCall, options, _meta
    }
}

public enum ACPPermissionOutcome: Equatable, Sendable {
    case cancelled
    case selected(optionID: String, _meta: ACPMeta? = nil)
}

extension ACPPermissionOutcome: Codable {
    private enum CodingKeys: String, CodingKey {
        case outcome
        case optionID = "optionId"
        case _meta
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        switch try container.decode(String.self, forKey: .outcome) {
        case "cancelled":
            self = .cancelled
        case "selected":
            self = .selected(
                optionID: try container.decode(String.self, forKey: .optionID),
                _meta: try? container.decodeIfPresent(ACPMeta.self, forKey: ._meta)
            )
        default:
            throw ACPJSONRPCError.invalidParams
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .cancelled:
            try container.encode("cancelled", forKey: .outcome)
        case .selected(let optionID, let _meta):
            try container.encode("selected", forKey: .outcome)
            try container.encode(optionID, forKey: .optionID)
            try container.encodeIfPresent(_meta, forKey: ._meta)
        }
    }
}

public struct ACPRequestPermissionResponse: Codable, Equatable, Sendable {
    public let outcome: ACPPermissionOutcome
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(outcome: ACPPermissionOutcome, _meta: ACPMeta? = nil) {
        self.outcome = outcome
        self._meta = _meta
    }
}
