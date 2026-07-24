import Foundation

public struct ACPContentToolCallContent: Codable, Equatable, Sendable {
    public let content: ACPContentBlock
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(content: ACPContentBlock, _meta: ACPMeta? = nil) {
        self.content = content
        self._meta = _meta
    }
}

public struct ACPDiffToolCallContent: Codable, Equatable, Sendable {
    public let path: String
    @ACPDefaultOnError public var oldText: String?
    public let newText: String
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(path: String, oldText: String? = nil, newText: String, _meta: ACPMeta? = nil) {
        self.path = path
        self.oldText = oldText
        self.newText = newText
        self._meta = _meta
    }
}

public struct ACPTerminalToolCallContent: Codable, Equatable, Sendable {
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

public enum ACPToolCallContent: Equatable, Sendable {
    case content(ACPContentToolCallContent)
    case diff(ACPDiffToolCallContent)
    case terminal(ACPTerminalToolCallContent)
}

extension ACPToolCallContent: Codable {
    public init(from decoder: Decoder) throws {
        switch try ACPTaggedCoding.tag("type", from: decoder) {
        case "content":
            self = .content(try ACPContentToolCallContent(from: decoder))
        case "diff":
            self = .diff(try ACPDiffToolCallContent(from: decoder))
        case "terminal":
            self = .terminal(try ACPTerminalToolCallContent(from: decoder))
        default:
            throw ACPJSONRPCError.invalidParams
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .content(let content):
            try ACPTaggedCoding.encode(content, tag: "content", key: "type", to: encoder)
        case .diff(let content):
            try ACPTaggedCoding.encode(content, tag: "diff", key: "type", to: encoder)
        case .terminal(let content):
            try ACPTaggedCoding.encode(content, tag: "terminal", key: "type", to: encoder)
        }
    }
}

public enum ACPToolKind: String, Codable, Equatable, Sendable {
    case read
    case edit
    case delete
    case move
    case search
    case execute
    case think
    case fetch
    case switchMode = "switch_mode"
    case other
}

public enum ACPToolCallStatus: String, Codable, Equatable, Sendable {
    case pending
    case inProgress = "in_progress"
    case completed
    case failed
}

public struct ACPToolCallLocation: Codable, Equatable, Sendable {
    public let path: String
    @ACPDefaultOnError public var line: UInt32?
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(path: String, line: UInt32? = nil, _meta: ACPMeta? = nil) {
        self.path = path
        self.line = line
        self._meta = _meta
    }
}

public struct ACPToolCall: Codable, Equatable, Sendable {
    public let toolCallID: String
    public let title: String
    @ACPDefaultOnError public var kind: ACPToolKind?
    @ACPDefaultOnError public var status: ACPToolCallStatus?
    @ACPLossyOptionalArray public var content: [ACPToolCallContent]?
    @ACPLossyOptionalArray public var locations: [ACPToolCallLocation]?
    @ACPDefaultOnError public var rawInput: ACPValue?
    @ACPDefaultOnError public var rawOutput: ACPValue?
    @ACPDefaultOnError public var _meta: ACPMeta?

    public var effectiveKind: ACPToolKind { kind ?? .other }
    public var effectiveStatus: ACPToolCallStatus { status ?? .pending }

    public init(
        toolCallID: String,
        title: String,
        kind: ACPToolKind? = nil,
        status: ACPToolCallStatus? = nil,
        content: [ACPToolCallContent]? = nil,
        locations: [ACPToolCallLocation]? = nil,
        rawInput: ACPValue? = nil,
        rawOutput: ACPValue? = nil,
        _meta: ACPMeta? = nil
    ) {
        self.toolCallID = toolCallID
        self.title = title
        self.kind = kind
        self.status = status
        self.content = content
        self.locations = locations
        self.rawInput = rawInput
        self.rawOutput = rawOutput
        self._meta = _meta
    }

    private enum CodingKeys: String, CodingKey {
        case toolCallID = "toolCallId"
        case title, kind, status, content, locations, rawInput, rawOutput, _meta
    }
}

public struct ACPToolCallUpdate: Equatable, Sendable {
    public let toolCallID: String
    public let kind: ACPField<ACPToolKind>
    public let status: ACPField<ACPToolCallStatus>
    public let title: ACPField<String>
    public let content: ACPField<[ACPToolCallContent]>
    public let locations: ACPField<[ACPToolCallLocation]>
    @ACPDefaultOnError public var rawInput: ACPValue?
    @ACPDefaultOnError public var rawOutput: ACPValue?
    public let _meta: ACPField<ACPMeta>

    public init(
        toolCallID: String,
        kind: ACPField<ACPToolKind> = .absent,
        status: ACPField<ACPToolCallStatus> = .absent,
        title: ACPField<String> = .absent,
        content: ACPField<[ACPToolCallContent]> = .absent,
        locations: ACPField<[ACPToolCallLocation]> = .absent,
        rawInput: ACPValue? = nil,
        rawOutput: ACPValue? = nil,
        _meta: ACPField<ACPMeta> = .absent
    ) {
        self.toolCallID = toolCallID
        self.kind = kind
        self.status = status
        self.title = title
        self.content = content
        self.locations = locations
        self.rawInput = rawInput
        self.rawOutput = rawOutput
        self._meta = _meta
    }
}

extension ACPToolCallUpdate: Codable {
    private enum CodingKeys: String, CodingKey {
        case toolCallID = "toolCallId"
        case kind
        case status
        case title
        case content
        case locations
        case rawInput
        case rawOutput
        case _meta
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        toolCallID = try container.decode(String.self, forKey: .toolCallID)
        kind = try container.decodeACPField(ACPToolKind.self, forKey: .kind)
        status = try container.decodeACPField(ACPToolCallStatus.self, forKey: .status)
        title = try container.decodeACPField(String.self, forKey: .title)
        content = container.decodeACPLossyArrayField(ACPToolCallContent.self, forKey: .content)
        locations = container.decodeACPLossyArrayField(ACPToolCallLocation.self, forKey: .locations)
        rawInput =
            container.contains(.rawInput)
            ? try container.decode(ACPValue.self, forKey: .rawInput)
            : nil
        rawOutput =
            container.contains(.rawOutput)
            ? try container.decode(ACPValue.self, forKey: .rawOutput)
            : nil
        _meta = try container.decodeACPField(ACPMeta.self, forKey: ._meta)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(toolCallID, forKey: .toolCallID)
        try container.encodeACPField(kind, forKey: .kind)
        try container.encodeACPField(status, forKey: .status)
        try container.encodeACPField(title, forKey: .title)
        try container.encodeACPField(content, forKey: .content)
        try container.encodeACPField(locations, forKey: .locations)
        try container.encodeIfPresent(rawInput, forKey: .rawInput)
        try container.encodeIfPresent(rawOutput, forKey: .rawOutput)
        try container.encodeACPField(_meta, forKey: ._meta)
    }
}
