import Foundation

public struct ACPCurrentModeUpdate: Codable, Equatable, Sendable {
    public let currentModeID: String
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(currentModeID: String, _meta: ACPMeta? = nil) {
        self.currentModeID = currentModeID
        self._meta = _meta
    }

    private enum CodingKeys: String, CodingKey {
        case currentModeID = "currentModeId"
        case _meta
    }
}

public struct ACPConfigOptionUpdate: Codable, Equatable, Sendable {
    @ACPRequiredLossyArray public var configOptions: [ACPSessionConfigOption]
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(configOptions: [ACPSessionConfigOption], _meta: ACPMeta? = nil) {
        self.configOptions = configOptions
        self._meta = _meta
    }
}

public struct ACPSessionInfoUpdate: Equatable, Sendable {
    public let title: ACPField<String>
    public let updatedAt: ACPField<String>
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(
        title: ACPField<String> = .absent,
        updatedAt: ACPField<String> = .absent,
        _meta: ACPMeta? = nil
    ) {
        self.title = title
        self.updatedAt = updatedAt
        self._meta = _meta
    }
}

extension ACPSessionInfoUpdate: Codable {
    private enum CodingKeys: String, CodingKey {
        case title
        case updatedAt
        case _meta
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeACPField(String.self, forKey: .title)
        updatedAt = try container.decodeACPField(String.self, forKey: .updatedAt)
        _meta = try? container.decodeIfPresent(ACPMeta.self, forKey: ._meta)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeACPField(title, forKey: .title)
        try container.encodeACPField(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(_meta, forKey: ._meta)
    }
}
