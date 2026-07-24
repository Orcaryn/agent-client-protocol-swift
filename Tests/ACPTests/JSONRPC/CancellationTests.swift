import Foundation
import Testing

@testable import ACP
import ACPModel

struct ACPConnectionCancellationTests {
    @Test func alreadyCancelledTaskSendsRequestBeforeCancellation() async throws {
        let transport = ControlledConnectionTransport()
        let connection = ACPConnection(transport: transport)
        try await connection.start()

        let request = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            let _: ACPEmptyResponse = try await connection.request(method: "already-cancelled")
        }

        let messages = await transport.waitForMessages(2)
        guard case .request(let requestID, let method, _) = messages[0],
            case .notification(let cancellationMethod, let params) = messages[1]
        else {
            Issue.record("Expected request followed by cancellation notification")
            return
        }

        #expect(method == "already-cancelled")
        #expect(cancellationMethod == ACPProtocol.Method.cancelRequest)
        #expect(try params?.decode(ACPCancelRequestNotification.self).requestID == requestID)

        await transport.emit(.response(id: requestID, result: .object([:])))
        try await request.value
        await connection.close()
    }

    @Test func cancellingTaskSendsProtocolCancellationButAcceptsNormalResponse() async throws {
        let transport = ControlledConnectionTransport()
        let connection = ACPConnection(transport: transport)
        try await connection.start()

        let request = Task {
            let _: ACPEmptyResponse = try await connection.request(
                method: "slow",
                params: ACPEmptyResponse()
            )
        }

        let sentRequest = await transport.waitForMessages(1)
        request.cancel()

        let messages = await transport.waitForMessages(2)
        guard case .request(let requestID, _, _) = sentRequest[0],
            case .notification(let method, let params) = messages[1]
        else {
            Issue.record("Expected request followed by a cancellation notification")
            return
        }

        #expect(method == ACPProtocol.Method.cancelRequest)
        #expect(
            try params?.decode(ACPCancelRequestNotification.self).requestID == requestID
        )

        await transport.emit(.response(id: requestID, result: .object([:])))
        try await request.value

        await connection.close()
    }

    @Test func cancelledTaskAcceptsRequestCancelledErrorFromPeer() async throws {
        let transport = ControlledConnectionTransport()
        let connection = ACPConnection(transport: transport)
        try await connection.start()

        let request = Task {
            let _: ACPEmptyResponse = try await connection.request(
                method: "slow",
                params: ACPEmptyResponse()
            )
        }

        let sent = await transport.waitForMessages(1)
        guard case .request(let id, _, _) = sent[0] else {
            Issue.record("Expected an outgoing request")
            return
        }

        request.cancel()
        _ = await transport.waitForMessages(2)
        await transport.emit(.error(id: id, error: .requestCancelled))

        do {
            try await request.value
            Issue.record("Expected the peer cancellation error")
        } catch let error as ACPJSONRPCError {
            #expect(error == .requestCancelled)
        }

        await connection.close()
    }

    @Test func cancellationAfterResponseDoesNotSendNotification() async throws {
        let transport = ControlledConnectionTransport()
        let connection = ACPConnection(transport: transport)
        try await connection.start()

        let request = Task {
            let _: ACPEmptyResponse = try await connection.request(method: "fast")
        }
        let sent = await transport.waitForMessages(1)
        guard case .request(let id, _, _) = sent[0] else {
            Issue.record("Expected an outgoing request")
            return
        }

        await transport.emit(.response(id: id, result: .object([:])))
        try await request.value
        request.cancel()
        await Task.yield()

        #expect(await transport.waitForMessages(1).count == 1)
        await connection.close()
    }

    @Test func cancellationForUnknownRequestIsIgnored() async throws {
        let transport = ControlledConnectionTransport()
        let connection = ACPConnection(transport: transport)
        try await connection.start()

        await transport.emit(
            .notification(
                method: ACPProtocol.Method.cancelRequest,
                params: try ACPValue.encode(
                    ACPCancelRequestNotification(requestID: .integer(999))
                )
            )
        )

        #expect(await transport.waitForMessages(0).isEmpty)
        await connection.close()
    }

    @Test func protocolCancellationCancelsInboundRequest() async throws {
        let transport = ControlledConnectionTransport()
        let connection = ACPConnection(
            transport: transport,
            handlers: ACPConnectionHandlers(
                onRequest: { _, _, _ in
                    try await Task.sleep(nanoseconds: 10_000_000_000)
                    return .null
                }
            )
        )
        try await connection.start()

        await transport.emit(
            .request(id: .integer(7), method: "slow", params: nil)
        )
        await transport.emit(
            .notification(
                method: ACPProtocol.Method.cancelRequest,
                params: try ACPValue.encode(
                    ACPCancelRequestNotification(requestID: .integer(7))
                )
            )
        )

        let messages = await transport.waitForMessages(1)
        guard case .error(let id, let error) = messages[0] else {
            Issue.record("Expected a request-cancelled response")
            return
        }

        #expect(id == .integer(7))
        #expect(error.code == .requestCancelled)

        await connection.close()
    }

    @Test func cancellingInboundRequestCancelsNestedOutboundRequest() async throws {
        let transport = ControlledConnectionTransport()
        let connection = ACPConnection(
            transport: transport,
            handlers: ACPConnectionHandlers(
                onRequest: { connection, _, _ in
                    let value: String = try await connection.request(method: "nested")
                    return .string(value)
                }
            )
        )
        try await connection.start()

        await transport.emit(.request(id: .integer(7), method: "outer", params: nil))
        let first = await transport.waitForMessages(1)
        guard case .request(let nestedID, let method, _) = first[0] else {
            Issue.record("Expected the nested request")
            return
        }
        #expect(method == "nested")

        await transport.emit(
            .notification(
                method: ACPProtocol.Method.cancelRequest,
                params: try ACPValue.encode(
                    ACPCancelRequestNotification(requestID: .integer(7))
                )
            )
        )

        let cancellation = await transport.waitForMessages(2)
        guard case .notification(let cancellationMethod, let params) = cancellation[1] else {
            Issue.record("Expected cancellation for nested request")
            return
        }
        #expect(cancellationMethod == ACPProtocol.Method.cancelRequest)
        #expect(try params?.decode(ACPCancelRequestNotification.self).requestID == nestedID)

        await transport.emit(.error(id: nestedID, error: .requestCancelled))
        let completed = await transport.waitForMessages(3)
        #expect(completed[2] == .error(id: .integer(7), error: .requestCancelled))

        await connection.close()
    }
}
