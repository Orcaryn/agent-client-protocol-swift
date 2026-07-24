import ACPModel

import Foundation

public enum ACPWireDirection: String, Sendable, Equatable {
    case incoming
    case outgoing
}

public enum ACPWireMessageKind: String, Sendable, Equatable {
    case request
    case notification
    case response
    case error
}

/// A sanitized description of a JSON-RPC message crossing an ACP connection.
public struct ACPWireEvent: Sendable, Equatable {
    public let direction: ACPWireDirection
    public let timestamp: Date
    public let kind: ACPWireMessageKind
    public let requestID: ACPRequestID?
    /// The request method. Responses and errors are correlated with their request when possible.
    public let method: String?
    /// Sanitized JSON, or `nil` when encoding failed or the configured size limit was exceeded.
    public let rawJSON: String?
    public let payloadOmitted: Bool

    public init(
        direction: ACPWireDirection,
        timestamp: Date,
        kind: ACPWireMessageKind,
        requestID: ACPRequestID?,
        method: String?,
        rawJSON: String?,
        payloadOmitted: Bool
    ) {
        self.direction = direction
        self.timestamp = timestamp
        self.kind = kind
        self.requestID = requestID
        self.method = method
        self.rawJSON = rawJSON
        self.payloadOmitted = payloadOmitted
    }
}

/// Opt-in wire inspection settings. No wire events are produced unless this is supplied.
///
/// JSON values under sensitive keys are recursively replaced before an event is emitted.
/// The default key matching is case-insensitive and ignores punctuation, so `api_key`,
/// `api-key`, and `apiKey` are treated equivalently.
public struct ACPWireInspection: Sendable {
    public typealias EventHandler = @Sendable (ACPWireEvent) async -> Void

    public static let defaultSensitiveKeys: Set<String> = [
        "accessToken",
        "apiKey",
        "authorization",
        "credential",
        "credentials",
        "password",
        "refreshToken",
        "secret",
        "token",
    ]

    public let sensitiveKeys: Set<String>
    public let replacement: String
    public let maximumRawJSONBytes: Int
    public let onEvent: EventHandler?
    private let normalizedSensitiveKeys: Set<String>

    public init(
        sensitiveKeys: Set<String> = ACPWireInspection.defaultSensitiveKeys,
        replacement: String = "<redacted>",
        maximumRawJSONBytes: Int = 64 * 1024,
        onEvent: EventHandler? = nil
    ) {
        self.sensitiveKeys = sensitiveKeys
        self.replacement = replacement
        self.maximumRawJSONBytes = max(0, maximumRawJSONBytes)
        self.onEvent = onEvent
        normalizedSensitiveKeys = Set(sensitiveKeys.map(Self.normalize))
    }

    func addingEventHandler(_ handler: @escaping EventHandler) -> ACPWireInspection {
        let existingHandler = onEvent
        return ACPWireInspection(
            sensitiveKeys: sensitiveKeys,
            replacement: replacement,
            maximumRawJSONBytes: maximumRawJSONBytes,
            onEvent: { event in
                await existingHandler?(event)
                await handler(event)
            }
        )
    }

    func makeEvent(
        for message: ACPJSONRPCMessage,
        direction: ACPWireDirection,
        method correlatedMethod: String?
    ) -> ACPWireEvent {
        let metadata = message.wireMetadata(correlatedMethod: correlatedMethod)
        let rawJSON = sanitizedJSON(for: message)

        return ACPWireEvent(
            direction: direction,
            timestamp: Date(),
            kind: metadata.kind,
            requestID: metadata.requestID,
            method: metadata.method,
            rawJSON: rawJSON,
            payloadOmitted: rawJSON == nil
        )
    }

    private func sanitizedJSON(for message: ACPJSONRPCMessage) -> String? {
        guard maximumRawJSONBytes > 0,
            let value = try? ACPValue.encode(message),
            let data = try? Self.encode(sanitize(value)),
            data.count <= maximumRawJSONBytes
        else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func sanitize(_ value: ACPValue) -> ACPValue {
        switch value {
        case .array(let values):
            return .array(values.map(sanitize))
        case .object(let object):
            return .object(
                object.reduce(into: [:]) { result, pair in
                    result[pair.key] =
                        normalizedSensitiveKeys.contains(Self.normalize(pair.key))
                        ? .string(replacement)
                        : sanitize(pair.value)
                })
        case .null, .bool, .integer, .unsigned, .double, .string:
            return value
        }
    }

    private static func normalize(_ key: String) -> String {
        String(key.lowercased().unicodeScalars.filter(CharacterSet.alphanumerics.contains))
    }

    private static func encode(_ value: ACPValue) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
}

private extension ACPJSONRPCMessage {
    func wireMetadata(
        correlatedMethod: String?
    ) -> (kind: ACPWireMessageKind, requestID: ACPRequestID?, method: String?) {
        switch self {
        case .request(let id, let method, _):
            return (.request, id, method)
        case .notification(let method, _):
            return (.notification, nil, method)
        case .response(let id, _):
            return (.response, id, correlatedMethod)
        case .error(let id, _):
            return (.error, id, correlatedMethod)
        }
    }
}
