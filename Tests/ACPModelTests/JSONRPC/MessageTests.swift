import Foundation
import Testing

@testable import ACPModel

struct ACPJSONRPCMessageTests {
    @Test func exposesJSONRPCErrorMessage() {
        let error = ACPJSONRPCError(
            code: .internalError,
            message: "Internal error",
            data: .object(["details": .string("provider-specific details")])
        )

        #expect(error.localizedDescription == "Internal error")
    }

    @Test func roundTripsEveryMessageShape() throws {
        let messages: [ACPJSONRPCMessage] = [
            .request(
                id: .integer(1),
                method: "initialize",
                params: .object(["protocolVersion": .integer(1)])
            ),
            .notification(
                method: "session/cancel",
                params: .object(["sessionId": .string("session-1")])
            ),
            .response(id: .string("request-2"), result: .null),
            .error(id: .integer(3), error: .methodNotFound),
            .error(id: .null, error: .invalidRequest),
        ]

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for message in messages {
            let data = try encoder.encode(message)
            let decoded = try decoder.decode(ACPJSONRPCMessage.self, from: data)
            #expect(decoded == message)
        }
    }

    @Test func rejectsUnsupportedJSONRPCVersion() throws {
        let data = Data(#"{"jsonrpc":"1.0","id":1,"result":null}"#.utf8)

        #expect(throws: ACPJSONRPCError.self) {
            try JSONDecoder().decode(ACPJSONRPCMessage.self, from: data)
        }
    }

    @Test func rejectsErrorResponseWithoutID() throws {
        let data = Data(
            #"{"jsonrpc":"2.0","error":{"code":-32603,"message":"Internal error"}}"#.utf8
        )

        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(ACPJSONRPCMessage.self, from: data)
        }
    }

    @Test func allowsExtensionMembersOnRequestEnvelopes() throws {
        let data = Data(
            #"{"jsonrpc":"2.0","id":1,"method":"echo","result":null}"#.utf8
        )

        let message = try JSONDecoder().decode(ACPJSONRPCMessage.self, from: data)
        #expect(message == .request(id: .integer(1), method: "echo", params: nil))
    }

    @Test func rejectsResponseWithResultAndError() {
        let data = Data(
            #"{"jsonrpc":"2.0","id":1,"result":null,"error":{"code":-32603,"message":"Internal error"}}"#.utf8
        )

        #expect(throws: ACPJSONRPCError.self) {
            try JSONDecoder().decode(ACPJSONRPCMessage.self, from: data)
        }
    }

    @Test func rejectsMalformedJSONRPCEnvelopeMatrix() {
        let malformed = [
            #"{"id":1,"method":"initialize"}"#,
            #"{"jsonrpc":"2.0","id":1}"#,
            #"{"jsonrpc":"2.0","id":{},"result":true}"#,
            #"{"jsonrpc":"2.0","id":1,"result":true,"error":{"code":-32603,"message":"Internal error"}}"#,
            #"{"jsonrpc":"2.0","id":1,"error":{"code":"-32603","message":"Error"}}"#,
            #"{"jsonrpc":"2.0","id":1,"error":{"code":-32603}}"#,
            #"{"jsonrpc":"2.0","id":{},"method":"initialize"}"#,
            #"{"jsonrpc":"2.0","id":1,"method":7}"#,
        ]

        for json in malformed {
            #expect(throws: (any Error).self, "Expected rejection for \(json)") {
                try JSONDecoder().decode(
                    ACPJSONRPCMessage.self,
                    from: Data(json.utf8)
                )
            }
        }
    }

    @Test func preservesCustomJSONRPCErrorCodesAndData() throws {
        let message = try JSONDecoder().decode(
            ACPJSONRPCMessage.self,
            from: Data(
                #"{"jsonrpc":"2.0","id":"custom","error":{"code":-32099,"message":"Vendor error","data":{"retry":false}}}"#
                    .utf8
            )
        )

        #expect(
            message
                == .error(
                    id: .string("custom"),
                    error: ACPJSONRPCError(
                        code: .other(-32099),
                        message: "Vendor error",
                        data: .object(["retry": .bool(false)])
                    )
                )
        )
    }

    @Test func typedValuesRoundTripThroughACPValue() throws {
        struct Value: Codable, Equatable {
            let name: String
            let enabled: Bool
            let count: Int
        }

        let original = Value(name: "Codex", enabled: true, count: 2)
        let value = try ACPValue.encode(original)
        let decoded = try value.decode(Value.self)

        #expect(decoded == original)
    }

    @Test func everyACPValueShapeRoundTrips() throws {
        let values: [ACPValue] = [
            .null,
            .bool(true),
            .integer(-1),
            .unsigned(UInt64.max),
            .double(1.5),
            .string("value"),
            .array([.integer(1)]),
            .object(["key": .string("value")]),
        ]

        for value in values {
            let data = try JSONEncoder().encode(value)
            #expect(try JSONDecoder().decode(ACPValue.self, from: data) == value)
        }
    }

    @Test func preservesLargeUnsignedValues() throws {
        let encoded = try ACPValue.encode(UInt64.max)

        #expect(encoded == .unsigned(UInt64.max))
        #expect(try encoded.decode(UInt64.self) == UInt64.max)
    }
}
