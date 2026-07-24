import Foundation

public struct ACPAuthMethod: Codable, Equatable, Identifiable, Sendable {
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

public struct ACPAuthenticateRequest: Codable, Equatable, Sendable {
    public let methodID: String
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(methodID: String, _meta: ACPMeta? = nil) {
        self.methodID = methodID
        self._meta = _meta
    }

    private enum CodingKeys: String, CodingKey {
        case methodID = "methodId"
        case _meta
    }
}

public typealias ACPAuthenticateResponse = ACPEmptyResponse
public typealias ACPLogoutRequest = ACPEmptyResponse
public typealias ACPLogoutResponse = ACPEmptyResponse
