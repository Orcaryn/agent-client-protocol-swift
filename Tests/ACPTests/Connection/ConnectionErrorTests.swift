import Foundation
import Testing

@testable import ACP
import ACPModel

struct ACPConnectionBehaviorTests {
    @Test func publicErrorsProvideActionableDescriptions() {
        #expect(ACPConnectionError.closed.errorDescription == "The ACP connection is closed.")
        #expect(
            ACPConnectionError.requestTimedOut(method: "session/prompt").errorDescription
                == "ACP request 'session/prompt' timed out."
        )
        #expect(ACPTransportError.notStarted.errorDescription == "The ACP transport has not started.")
        #expect(
            ACPTransportTermination.processExited(9).errorDescription
                == "The ACP process exited with status 9."
        )
    }
    @Test func decodingFailureReturnsInvalidParams() async throws {
        struct Params: Decodable { let required: String }

        let transport = ControlledConnectionTransport()
        let events = ConnectionTestEvents()
        let connection = ACPConnection(
            transport: transport,
            handlers: ACPConnectionHandlers(onRequest: { _, _, params in
                await events.append("called")
                _ = try params?.decode(Params.self)
                return .null
            })
        )
        try await connection.start()

        await transport.emit(.request(id: .integer(1), method: "typed", params: .object([:])))
        let sent = await transport.waitForMessages(1)

        #expect(await events.values == ["called"])
        #expect(sent == [.error(id: .integer(1), error: .invalidParams)])
        await connection.close()
    }
    @Test func jsonRPCHandlerErrorPreservesCodeMessageAndData() async throws {
        let expected = ACPJSONRPCError(
            code: .authRequired,
            message: "sign in first",
            data: .object(["provider": .string("example")])
        )
        let transport = ControlledConnectionTransport()
        let connection = ACPConnection(
            transport: transport,
            handlers: ACPConnectionHandlers(onRequest: { _, _, _ in throw expected })
        )
        try await connection.start()

        await transport.emit(.request(id: .string("a"), method: "protected", params: nil))
        #expect(await transport.waitForMessages(1) == [.error(id: .string("a"), error: expected)])
        await connection.close()
    }
    @Test func arbitraryHandlerErrorReturnsInternalError() async throws {
        let transport = ControlledConnectionTransport()
        let connection = ACPConnection(
            transport: transport,
            handlers: ACPConnectionHandlers(onRequest: { _, _, _ in
                throw ConnectionTestFailure.handler
            })
        )
        try await connection.start()

        await transport.emit(.request(id: .integer(3), method: "explode", params: nil))
        let sent = await transport.waitForMessages(1)
        guard case .error(let id, let error) = sent[0] else {
            Issue.record("Expected an error response")
            return
        }
        #expect(id == .integer(3))
        #expect(error.code == .internalError)
        #expect(error == .internalError)
        await connection.close()
    }
}
