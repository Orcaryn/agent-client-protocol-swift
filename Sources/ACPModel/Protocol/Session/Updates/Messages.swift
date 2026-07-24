import Foundation

public struct ACPContentChunk: Codable, Equatable, Sendable {
    public let content: ACPContentBlock
    @ACPDefaultOnError public var messageID: String?
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(content: ACPContentBlock, messageID: String? = nil, _meta: ACPMeta? = nil) {
        self.content = content
        self.messageID = messageID
        self._meta = _meta
    }

    private enum CodingKeys: String, CodingKey {
        case content
        case messageID = "messageId"
        case _meta
    }
}
