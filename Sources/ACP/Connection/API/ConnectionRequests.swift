import ACPModel

import Foundation
import OSLog

extension ACPConnection {
    public func request<Params: Encodable & Sendable, Response: Decodable & Sendable>(
        method: String,
        params: Params,
        response: Response.Type = Response.self
    ) async throws -> Response {
        let value = try ACPValue.encode(params)
        let result = try await requestValue(method: method, params: value)
        return try result.decode(response)
    }

    public func request<Response: Decodable & Sendable>(
        method: String,
        response: Response.Type = Response.self
    ) async throws -> Response {
        let result = try await requestValue(method: method, params: nil)
        return try result.decode(response)
    }

    func requestAfterPrecedingNotifications<
        Params: Encodable & Sendable,
        Response: Decodable & Sendable
    >(
        method: String,
        params: Params,
        response: Response.Type = Response.self
    ) async throws -> Response {
        let value = try ACPValue.encode(params)
        let result = try await requestValue(
            method: method,
            params: value,
            waitsForPrecedingNotifications: !isInsideNotificationCallback
        )
        return try result.decode(response)
    }

    public func notify<Params: Encodable & Sendable>(method: String, params: Params) async throws {
        guard canSend else {
            throw ACPConnectionError.closed
        }

        let value = try ACPValue.encode(params)
        acpConnectionLogger.debug("Sending notification method=\(method, privacy: .public)")
        try await sendMessage(.notification(method: method, params: value))
    }

    /// Starts closing without waiting for callbacks to drain.
    ///
    /// This is the safe shutdown entry point from a connection callback.
    public func beginClose() {
        switch lifecycle.phase {
        case .closed, .closing, .draining:
            break
        case .idle:
            finishWithoutTransport()
        case .running:
            lifecycle.phase = .closing
            Task { [transport] in
                await transport.terminate()
            }
        }
    }

    /// Starts closing and waits until queued callbacks have drained.
    ///
    /// Connection callbacks should call ``beginClose()`` instead to avoid waiting on themselves.
    public func close() async {
        beginClose()
        _ = await waitUntilClosed()
    }

    /// Waits until transport termination and all queued callbacks have finished.
    public func waitUntilClosed() async -> ACPTransportTermination {
        if let termination = lifecycle.termination {
            return termination
        }

        return await withCheckedContinuation { continuation in
            lifecycle.closeWaiters.append(continuation)
        }
    }
}
