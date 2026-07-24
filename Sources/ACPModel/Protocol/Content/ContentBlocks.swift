import Foundation

public enum ACPRole: String, Codable, Equatable, Sendable {
    case assistant
    case user
}

public struct ACPAnnotations: Codable, Equatable, Sendable {
    @ACPLossyOptionalArray public var audience: [ACPRole]?
    @ACPDefaultOnError public var lastModified: String?
    @ACPDefaultOnError public var priority: Double?
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(
        audience: [ACPRole]? = nil,
        lastModified: String? = nil,
        priority: Double? = nil,
        _meta: ACPMeta? = nil
    ) {
        self.audience = audience
        self.lastModified = lastModified
        self.priority = priority
        self._meta = _meta
    }
}

public struct ACPTextContent: Codable, Equatable, Sendable {
    @ACPDefaultOnError public var annotations: ACPAnnotations?
    public let text: String
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(text: String, annotations: ACPAnnotations? = nil, _meta: ACPMeta? = nil) {
        self.annotations = annotations
        self.text = text
        self._meta = _meta
    }
}

public struct ACPImageContent: Codable, Equatable, Sendable {
    @ACPDefaultOnError public var annotations: ACPAnnotations?
    public let data: String
    public let mimeType: String
    @ACPDefaultOnError public var uri: String?
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(
        data: String,
        mimeType: String,
        uri: String? = nil,
        annotations: ACPAnnotations? = nil,
        _meta: ACPMeta? = nil
    ) {
        self.annotations = annotations
        self.data = data
        self.mimeType = mimeType
        self.uri = uri
        self._meta = _meta
    }
}

public struct ACPAudioContent: Codable, Equatable, Sendable {
    @ACPDefaultOnError public var annotations: ACPAnnotations?
    public let data: String
    public let mimeType: String
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(
        data: String,
        mimeType: String,
        annotations: ACPAnnotations? = nil,
        _meta: ACPMeta? = nil
    ) {
        self.annotations = annotations
        self.data = data
        self.mimeType = mimeType
        self._meta = _meta
    }
}

public enum ACPContentBlock: Equatable, Sendable {
    case text(ACPTextContent)
    case image(ACPImageContent)
    case audio(ACPAudioContent)
    case resourceLink(ACPResourceLink)
    case resource(ACPEmbeddedResource)
}

extension ACPContentBlock: Codable {
    public init(from decoder: Decoder) throws {
        switch try ACPTaggedCoding.tag("type", from: decoder) {
        case "text":
            self = .text(try ACPTextContent(from: decoder))
        case "image":
            self = .image(try ACPImageContent(from: decoder))
        case "audio":
            self = .audio(try ACPAudioContent(from: decoder))
        case "resource_link":
            self = .resourceLink(try ACPResourceLink(from: decoder))
        case "resource":
            self = .resource(try ACPEmbeddedResource(from: decoder))
        default:
            throw ACPJSONRPCError.invalidParams
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let content):
            try ACPTaggedCoding.encode(content, tag: "text", key: "type", to: encoder)
        case .image(let content):
            try ACPTaggedCoding.encode(content, tag: "image", key: "type", to: encoder)
        case .audio(let content):
            try ACPTaggedCoding.encode(content, tag: "audio", key: "type", to: encoder)
        case .resourceLink(let content):
            try ACPTaggedCoding.encode(content, tag: "resource_link", key: "type", to: encoder)
        case .resource(let content):
            try ACPTaggedCoding.encode(content, tag: "resource", key: "type", to: encoder)
        }
    }
}
