import Foundation

/// A semantic category used to group session configuration options in client UIs.
///
/// ACP defines several well-known categories, while allowing agents to send
/// additional category values. Unknown values are therefore preserved through
/// the public `rawValue` rather than rejected during decoding.
public struct ACPSessionConfigOptionCategory: RawRepresentable, Codable, Equatable, Hashable,
    Sendable
{
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let mode = Self(rawValue: "mode")
    public static let model = Self(rawValue: "model")
    public static let modelConfig = Self(rawValue: "model_config")
    public static let thoughtLevel = Self(rawValue: "thought_level")

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct ACPSessionMode: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    @ACPDefaultOnError public var description: String?
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(id: String, name: String, description: String? = nil, _meta: ACPMeta? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self._meta = _meta
    }
}

public struct ACPSessionModeState: Codable, Equatable, Sendable {
    public let currentModeID: String
    @ACPRequiredLossyArray public var availableModes: [ACPSessionMode]
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(
        currentModeID: String,
        availableModes: [ACPSessionMode],
        _meta: ACPMeta? = nil
    ) {
        self.currentModeID = currentModeID
        self.availableModes = availableModes
        self._meta = _meta
    }

    private enum CodingKeys: String, CodingKey {
        case currentModeID = "currentModeId"
        case availableModes, _meta
    }
}

public struct ACPSetSessionModeRequest: Codable, Equatable, Sendable {
    public let sessionID: String
    public let modeID: String
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(sessionID: String, modeID: String, _meta: ACPMeta? = nil) {
        self.sessionID = sessionID
        self.modeID = modeID
        self._meta = _meta
    }

    private enum CodingKeys: String, CodingKey {
        case sessionID = "sessionId"
        case modeID = "modeId"
        case _meta
    }
}

public typealias ACPSetSessionModeResponse = ACPEmptyResponse
