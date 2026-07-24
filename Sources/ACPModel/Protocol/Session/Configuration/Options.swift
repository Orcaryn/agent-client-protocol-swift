import Foundation

public struct ACPSessionConfigSelectOption: Codable, Equatable, Sendable {
    public let value: String
    public let name: String
    @ACPDefaultOnError public var description: String?
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(value: String, name: String, description: String? = nil, _meta: ACPMeta? = nil) {
        self.value = value
        self.name = name
        self.description = description
        self._meta = _meta
    }
}

public struct ACPSessionConfigSelectGroup: Codable, Equatable, Sendable {
    public let group: String
    public let name: String
    @ACPRequiredLossyArray public var options: [ACPSessionConfigSelectOption]
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(
        group: String,
        name: String,
        options: [ACPSessionConfigSelectOption],
        _meta: ACPMeta? = nil
    ) {
        self.group = group
        self.name = name
        self.options = options
        self._meta = _meta
    }
}

public enum ACPSessionConfigSelectOptions: Equatable, Sendable {
    case ungrouped([ACPSessionConfigSelectOption])
    case grouped([ACPSessionConfigSelectGroup])
}

extension ACPSessionConfigSelectOptions: Codable {
    public init(from decoder: Decoder) throws {
        let value = try ACPValue(from: decoder)
        let values: [ACPValue]

        if case .array(let array) = value {
            values = array
        } else {
            throw ACPJSONRPCError.invalidParams
        }

        if values.first?.objectValue?["group"] != nil {
            self = .grouped(try value.decode([ACPSessionConfigSelectGroup].self))
        } else {
            self = .ungrouped(try value.decode([ACPSessionConfigSelectOption].self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .ungrouped(let options):
            try options.encode(to: encoder)
        case .grouped(let groups):
            try groups.encode(to: encoder)
        }
    }
}

public struct ACPSessionConfigSelect: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    @ACPDefaultOnError public var description: String?
    @ACPDefaultOnError public var category: ACPSessionConfigOptionCategory?
    public let currentValue: String
    public let options: ACPSessionConfigSelectOptions
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(
        id: String,
        name: String,
        currentValue: String,
        options: ACPSessionConfigSelectOptions,
        description: String? = nil,
        category: ACPSessionConfigOptionCategory? = nil,
        _meta: ACPMeta? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.currentValue = currentValue
        self.options = options
        self._meta = _meta
    }
}

public struct ACPSessionConfigBoolean: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    @ACPDefaultOnError public var description: String?
    @ACPDefaultOnError public var category: ACPSessionConfigOptionCategory?
    public let currentValue: Bool
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(
        id: String,
        name: String,
        currentValue: Bool,
        description: String? = nil,
        category: ACPSessionConfigOptionCategory? = nil,
        _meta: ACPMeta? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.currentValue = currentValue
        self._meta = _meta
    }
}

public enum ACPSessionConfigOption: Equatable, Identifiable, Sendable {
    case select(ACPSessionConfigSelect)
    case boolean(ACPSessionConfigBoolean)

    public var id: String {
        switch self {
        case .select(let option):
            option.id
        case .boolean(let option):
            option.id
        }
    }
}

extension ACPSessionConfigOption: Codable {
    public init(from decoder: Decoder) throws {
        switch try ACPTaggedCoding.tag("type", from: decoder) {
        case "select":
            self = .select(try ACPSessionConfigSelect(from: decoder))
        case "boolean":
            self = .boolean(try ACPSessionConfigBoolean(from: decoder))
        default:
            throw ACPJSONRPCError.invalidParams
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .select(let option):
            try ACPTaggedCoding.encode(option, tag: "select", key: "type", to: encoder)
        case .boolean(let option):
            try ACPTaggedCoding.encode(option, tag: "boolean", key: "type", to: encoder)
        }
    }
}

public enum ACPSessionConfigValue: Equatable, Sendable {
    case boolean(Bool)
    case valueID(String)
}

public struct ACPSetConfigOptionRequest: Equatable, Sendable {
    public let sessionID: String
    public let configID: String
    public let value: ACPSessionConfigValue
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(
        sessionID: String,
        configID: String,
        value: ACPSessionConfigValue,
        _meta: ACPMeta? = nil
    ) {
        self.sessionID = sessionID
        self.configID = configID
        self.value = value
        self._meta = _meta
    }
}

extension ACPSetConfigOptionRequest: Codable {
    private enum CodingKeys: String, CodingKey {
        case sessionID = "sessionId"
        case configID = "configId"
        case value
        case type
        case _meta
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionID = try container.decode(String.self, forKey: .sessionID)
        configID = try container.decode(String.self, forKey: .configID)
        _meta = try? container.decodeIfPresent(ACPMeta.self, forKey: ._meta)

        if (try? container.decodeIfPresent(String.self, forKey: .type)) == "boolean" {
            value = .boolean(try container.decode(Bool.self, forKey: .value))
        } else {
            value = .valueID(try container.decode(String.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sessionID, forKey: .sessionID)
        try container.encode(configID, forKey: .configID)
        try container.encodeIfPresent(_meta, forKey: ._meta)

        switch value {
        case .boolean(let value):
            try container.encode("boolean", forKey: .type)
            try container.encode(value, forKey: .value)
        case .valueID(let value):
            try container.encode(value, forKey: .value)
        }
    }
}

public struct ACPSetConfigOptionResponse: Codable, Equatable, Sendable {
    @ACPRequiredLossyArray public var configOptions: [ACPSessionConfigOption]
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(configOptions: [ACPSessionConfigOption], _meta: ACPMeta? = nil) {
        self.configOptions = configOptions
        self._meta = _meta
    }
}
