import Foundation

public struct ACPResourceLink: Codable, Equatable, Sendable {
    @ACPDefaultOnError public var annotations: ACPAnnotations?
    @ACPDefaultOnError public var description: String?
    @ACPDefaultOnError public var mimeType: String?
    public let name: String
    @ACPDefaultOnError public var size: Int64?
    @ACPDefaultOnError public var title: String?
    public let uri: String
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(
        uri: String,
        name: String,
        annotations: ACPAnnotations? = nil,
        description: String? = nil,
        mimeType: String? = nil,
        size: Int64? = nil,
        title: String? = nil,
        _meta: ACPMeta? = nil
    ) {
        self.annotations = annotations
        self.description = description
        self.mimeType = mimeType
        self.name = name
        self.size = size
        self.title = title
        self.uri = uri
        self._meta = _meta
    }
}

public struct ACPTextResourceContents: Codable, Equatable, Sendable {
    @ACPDefaultOnError public var mimeType: String?
    public let text: String
    public let uri: String
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(uri: String, text: String, mimeType: String? = nil, _meta: ACPMeta? = nil) {
        self.mimeType = mimeType
        self.text = text
        self.uri = uri
        self._meta = _meta
    }
}

public struct ACPBlobResourceContents: Codable, Equatable, Sendable {
    public let blob: String
    @ACPDefaultOnError public var mimeType: String?
    public let uri: String
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(uri: String, blob: String, mimeType: String? = nil, _meta: ACPMeta? = nil) {
        self.blob = blob
        self.mimeType = mimeType
        self.uri = uri
        self._meta = _meta
    }
}

public enum ACPEmbeddedResourceContents: Equatable, Sendable {
    case text(ACPTextResourceContents)
    case blob(ACPBlobResourceContents)
}

extension ACPEmbeddedResourceContents: Codable {
    public init(from decoder: Decoder) throws {
        let value = try ACPValue(from: decoder)

        if value.objectValue?["text"] != nil {
            self = .text(try value.decode(ACPTextResourceContents.self))
            return
        }

        if value.objectValue?["blob"] != nil {
            self = .blob(try value.decode(ACPBlobResourceContents.self))
            return
        }

        throw ACPJSONRPCError.invalidParams
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let content):
            try content.encode(to: encoder)
        case .blob(let content):
            try content.encode(to: encoder)
        }
    }
}

public struct ACPEmbeddedResource: Codable, Equatable, Sendable {
    @ACPDefaultOnError public var annotations: ACPAnnotations?
    public let resource: ACPEmbeddedResourceContents
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(
        resource: ACPEmbeddedResourceContents,
        annotations: ACPAnnotations? = nil,
        _meta: ACPMeta? = nil
    ) {
        self.annotations = annotations
        self.resource = resource
        self._meta = _meta
    }
}
