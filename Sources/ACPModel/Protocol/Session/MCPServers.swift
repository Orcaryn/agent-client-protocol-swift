import Foundation

public struct ACPEnvironmentVariable: Codable, Equatable, Sendable {
    public let name: String
    public let value: String
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(name: String, value: String, _meta: ACPMeta? = nil) {
        self.name = name
        self.value = value
        self._meta = _meta
    }
}

public struct ACPHTTPHeader: Codable, Equatable, Sendable {
    public let name: String
    public let value: String
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(name: String, value: String, _meta: ACPMeta? = nil) {
        self.name = name
        self.value = value
        self._meta = _meta
    }
}

public struct ACPMCPHTTPServer: Codable, Equatable, Sendable {
    public let name: String
    public let url: String
    public let headers: [ACPHTTPHeader]
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(name: String, url: String, headers: [ACPHTTPHeader], _meta: ACPMeta? = nil) {
        self.name = name
        self.url = url
        self.headers = headers
        self._meta = _meta
    }
}

public struct ACPMCPSSEServer: Codable, Equatable, Sendable {
    public let name: String
    public let url: String
    public let headers: [ACPHTTPHeader]
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(name: String, url: String, headers: [ACPHTTPHeader], _meta: ACPMeta? = nil) {
        self.name = name
        self.url = url
        self.headers = headers
        self._meta = _meta
    }
}

public struct ACPMCPStdioServer: Codable, Equatable, Sendable {
    public let name: String
    public let command: String
    public let args: [String]
    public let env: [ACPEnvironmentVariable]
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(
        name: String,
        command: String,
        args: [String],
        env: [ACPEnvironmentVariable],
        _meta: ACPMeta? = nil
    ) {
        self.name = name
        self.command = command
        self.args = args
        self.env = env
        self._meta = _meta
    }
}

public enum ACPMCPServer: Equatable, Sendable {
    case http(ACPMCPHTTPServer)
    case sse(ACPMCPSSEServer)
    case stdio(ACPMCPStdioServer)
}

extension ACPMCPServer: Codable {
    public init(from decoder: Decoder) throws {
        let value = try ACPValue(from: decoder)

        switch value.objectValue?["type"]?.stringValue {
        case "http":
            self = .http(try value.decode(ACPMCPHTTPServer.self))
        case "sse":
            self = .sse(try value.decode(ACPMCPSSEServer.self))
        default:
            self = .stdio(try value.decode(ACPMCPStdioServer.self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .http(let server):
            try ACPTaggedCoding.encode(server, tag: "http", key: "type", to: encoder)
        case .sse(let server):
            try ACPTaggedCoding.encode(server, tag: "sse", key: "type", to: encoder)
        case .stdio(let server):
            try server.encode(to: encoder)
        }
    }
}
