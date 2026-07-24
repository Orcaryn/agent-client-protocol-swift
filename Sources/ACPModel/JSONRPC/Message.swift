import Foundation

public enum ACPRequestID: Codable, Hashable, Sendable {
    case null
    case integer(Int64)
    case string(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Int64.self) {
            self = .integer(value)
        } else {
            self = .string(try container.decode(String.self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .null:
            try container.encodeNil()
        case .integer(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        }
    }
}

public enum ACPErrorCode: Codable, Equatable, Sendable {
    case parseError
    case invalidRequest
    case methodNotFound
    case invalidParams
    case internalError
    case requestCancelled
    case authRequired
    case resourceNotFound
    case other(Int32)

    public init(rawValue: Int32) {
        switch rawValue {
        case -32700:
            self = .parseError
        case -32600:
            self = .invalidRequest
        case -32601:
            self = .methodNotFound
        case -32602:
            self = .invalidParams
        case -32603:
            self = .internalError
        case -32800:
            self = .requestCancelled
        case -32000:
            self = .authRequired
        case -32002:
            self = .resourceNotFound
        default:
            self = .other(rawValue)
        }
    }

    public var rawValue: Int32 {
        switch self {
        case .parseError:
            -32700
        case .invalidRequest:
            -32600
        case .methodNotFound:
            -32601
        case .invalidParams:
            -32602
        case .internalError:
            -32603
        case .requestCancelled:
            -32800
        case .authRequired:
            -32000
        case .resourceNotFound:
            -32002
        case .other(let value):
            value
        }
    }

    public init(from decoder: Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(Int32.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct ACPJSONRPCError: Codable, Error, Equatable, LocalizedError, Sendable {
    public let code: ACPErrorCode
    public let message: String
    public let data: ACPValue?

    public init(code: ACPErrorCode, message: String, data: ACPValue? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }

    public static let parseError = ACPJSONRPCError(code: .parseError, message: "Parse error")
    public static let invalidRequest = ACPJSONRPCError(code: .invalidRequest, message: "Invalid Request")
    public static let methodNotFound = ACPJSONRPCError(code: .methodNotFound, message: "Method not found")
    public static let invalidParams = ACPJSONRPCError(code: .invalidParams, message: "Invalid params")
    public static let internalError = ACPJSONRPCError(code: .internalError, message: "Internal error")
    public static let requestCancelled = ACPJSONRPCError(code: .requestCancelled, message: "Request cancelled")
    public static let authRequired = ACPJSONRPCError(code: .authRequired, message: "Authentication required")
    public static let resourceNotFound = ACPJSONRPCError(code: .resourceNotFound, message: "Resource not found")

    public var errorDescription: String? {
        message
    }
}

public enum ACPJSONRPCMessage: Equatable, Sendable {
    case request(id: ACPRequestID, method: String, params: ACPValue?)
    case notification(method: String, params: ACPValue?)
    case response(id: ACPRequestID, result: ACPValue)
    case error(id: ACPRequestID, error: ACPJSONRPCError)
}

extension ACPJSONRPCMessage: Codable {
    private enum CodingKeys: String, CodingKey {
        case jsonrpc
        case id
        case method
        case params
        case result
        case error
    }

    private static let version = "2.0"

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(String.self, forKey: .jsonrpc)

        if version != Self.version {
            throw ACPJSONRPCError.invalidRequest
        }

        if let method = try container.decodeIfPresent(String.self, forKey: .method) {
            let params =
                container.contains(.params)
                ? try container.decode(ACPValue.self, forKey: .params)
                : nil

            if container.contains(.id) {
                let id = try container.decode(ACPRequestID.self, forKey: .id)
                self = .request(id: id, method: method, params: params)
            } else {
                self = .notification(method: method, params: params)
            }

            return
        }

        let hasResult = container.contains(.result)
        let hasError = container.contains(.error)

        if hasResult == hasError {
            throw ACPJSONRPCError.invalidRequest
        }

        let id = try container.decode(ACPRequestID.self, forKey: .id)

        if hasError {
            let error = try container.decode(ACPJSONRPCError.self, forKey: .error)
            self = .error(id: id, error: error)
            return
        }

        let result = try container.decode(ACPValue.self, forKey: .result)
        self = .response(id: id, result: result)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.version, forKey: .jsonrpc)

        switch self {
        case .request(let id, let method, let params):
            try container.encode(id, forKey: .id)
            try container.encode(method, forKey: .method)
            try container.encodeIfPresent(params, forKey: .params)

        case .notification(let method, let params):
            try container.encode(method, forKey: .method)
            try container.encodeIfPresent(params, forKey: .params)

        case .response(let id, let result):
            try container.encode(id, forKey: .id)
            try container.encode(result, forKey: .result)

        case .error(let id, let error):
            try container.encode(id, forKey: .id)
            try container.encode(error, forKey: .error)
        }
    }
}

public struct ACPCancelRequestNotification: Codable, Equatable, Sendable {
    public let requestID: ACPRequestID
    public var _meta: ACPMeta?

    public init(requestID: ACPRequestID, _meta: ACPMeta? = nil) {
        self.requestID = requestID
        self._meta = _meta
    }

    private enum CodingKeys: String, CodingKey {
        case requestID = "requestId"
        case _meta
    }
}
