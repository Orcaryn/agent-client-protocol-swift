import Foundation
import Testing

@testable import ACPModel

struct WireCodingTests {
    @Test func patchFieldsEncodeAbsentNullAndValueExactly() throws {
        try expectEncodedJSON(
            ACPToolCallUpdate(toolCallID: "tool-1"),
            #"{"toolCallId":"tool-1"}"#
        )
        try expectEncodedJSON(
            ACPToolCallUpdate(
                toolCallID: "tool-1",
                kind: .null,
                status: .value(.failed),
                title: .null,
                content: .value([]),
                locations: .null
            ),
            #"{"toolCallId":"tool-1","kind":null,"status":"failed","title":null,"content":[],"locations":null}"#
        )
        try expectEncodedJSON(
            ACPSessionInfoUpdate(),
            #"{}"#
        )
        try expectEncodedJSON(
            ACPSessionInfoUpdate(title: .null, updatedAt: .value("2026-07-12T12:00:00Z")),
            #"{"title":null,"updatedAt":"2026-07-12T12:00:00Z"}"#
        )

        let invalidScalars = try decode(
            ACPToolCallUpdate.self,
            #"{"toolCallId":"tool-1","kind":4,"status":{},"title":false,"content":"bad","locations":7}"#
        )
        #expect(invalidScalars.kind == .absent)
        #expect(invalidScalars.status == .absent)
        #expect(invalidScalars.title == .absent)
        #expect(invalidScalars.content == .absent)
        #expect(invalidScalars.locations == .absent)
        try expectEncodedJSON(invalidScalars, #"{"toolCallId":"tool-1"}"#)
    }

    @Test func requiredLossyArraysEnforcePresenceAndDropInvalidMembers() throws {
        for json in [#"{}"#, #"{"entries":null}"#, #"{"entries":"invalid"}"#] {
            if json == #"{}"# {
                #expect(throws: DecodingError.self) { try decode(ACPPlan.self, json) }
            } else {
                let plan = try decode(ACPPlan.self, json)
                #expect(plan.entries == [])
            }
        }

        let plan = try decode(
            ACPPlan.self,
            #"{"entries":[{"content":"keep","priority":"high","status":"pending"},{"content":"bad-priority","priority":"urgent","status":"pending"},4]}"#
        )
        #expect(plan.entries == [ACPPlanEntry(content: "keep", priority: .high, status: .pending)])

        #expect(throws: DecodingError.self) {
            try decode(ACPListSessionsResponse.self, #"{}"#)
        }
        let sessions = try decode(
            ACPListSessionsResponse.self,
            #"{"sessions":[{"sessionId":"one","cwd":"/one"},{"sessionId":2,"cwd":"/bad"}]}"#
        )
        #expect(sessions.sessions.map(\.sessionID) == ["one"])

        #expect(throws: DecodingError.self) {
            try decode(ACPNewSessionRequest.self, #"{"cwd":"/tmp"}"#)
        }
        let request = try decode(
            ACPNewSessionRequest.self,
            #"{"cwd":"/tmp","mcpServers":[{"name":"ok","command":"mcp","args":[],"env":[]},{"type":"http","name":"bad"}]}"#
        )
        #expect(
            request.mcpServers == [
                .stdio(ACPMCPStdioServer(name: "ok", command: "mcp", args: [], env: []))
            ])
    }

    @Test func optionalLossyArraysDistinguishAbsenceNullInvalidAndValues() throws {
        let absent = try decode(ACPNewSessionRequest.self, #"{"cwd":"/tmp","mcpServers":[]}"#)
        let null = try decode(
            ACPNewSessionRequest.self, #"{"cwd":"/tmp","mcpServers":[],"additionalDirectories":null}"#)
        let invalid = try decode(
            ACPNewSessionRequest.self, #"{"cwd":"/tmp","mcpServers":[],"additionalDirectories":4}"#)
        let mixed = try decode(
            ACPNewSessionRequest.self, #"{"cwd":"/tmp","mcpServers":[],"additionalDirectories":["/one",4,"/two"]}"#)

        #expect(absent.additionalDirectories == nil)
        #expect(null.additionalDirectories == nil)
        #expect(invalid.additionalDirectories == nil)
        #expect(mixed.additionalDirectories == ["/one", "/two"])
        try expectEncodedJSON(absent, #"{"cwd":"/tmp","mcpServers":[]}"#)
        try expectEncodedJSON(null, #"{"cwd":"/tmp","mcpServers":[]}"#)
        try expectEncodedJSON(invalid, #"{"cwd":"/tmp","mcpServers":[]}"#)

        let toolCall = try decode(
            ACPToolCall.self,
            #"{"toolCallId":"tool-1","title":"Run","content":[{"type":"terminal","terminalId":"term-1"},{"type":"unknown"}],"locations":[{"path":"/tmp/file"},{"path":4}]}"#
        )
        #expect(toolCall.content == [.terminal(ACPTerminalToolCallContent(terminalID: "term-1"))])
        #expect(toolCall.locations == [ACPToolCallLocation(path: "/tmp/file")])
    }

    @Test func taggedUnionsRejectMissingWrongAndUnknownDiscriminators() {
        for json in [
            #"{}"#,
            #"{"type":4,"text":"hello"}"#,
            #"{"type":"unknown","text":"hello"}"#,
        ] {
            #expect(throws: ACPJSONRPCError.self) {
                try decode(ACPContentBlock.self, json)
            }
        }

        for json in [
            #"{"type":"diff","path":"/tmp/file"}"#,
            #"{"type":"terminal"}"#,
            #"{"type":"unknown","terminalId":"term-1"}"#,
        ] {
            #expect(throws: Error.self) {
                try decode(ACPToolCallContent.self, json)
            }
        }

        for json in [
            #"{}"#,
            #"{"sessionUpdate":4}"#,
            #"{"sessionUpdate":"unknown"}"#,
        ] {
            #expect(throws: ACPJSONRPCError.self) {
                try decode(ACPSessionUpdate.self, json)
            }
        }
    }

    @Test func appliesSchemaDirectedLossyDecoding() throws {
        let initialization = try JSONDecoder().decode(
            ACPInitializeResponse.self,
            from: Data(
                #"{"protocolVersion":1,"agentCapabilities":{"loadSession":"invalid"},"authMethods":[{"id":"valid","name":"Valid"},{"id":4}]}"#
                    .utf8
            )
        )
        #expect(initialization.agentCapabilities.loadSession == false)
        #expect(initialization.agentCapabilities.promptCapabilities.image == false)
        #expect(initialization.agentCapabilities.mcpCapabilities.http == false)
        #expect(initialization.authMethods.map(\.id) == ["valid"])

        let malformedOptionalInitialization = try JSONDecoder().decode(
            ACPInitializeResponse.self,
            from: Data(#"{"protocolVersion":1,"agentInfo":"invalid"}"#.utf8)
        )
        #expect(malformedOptionalInitialization.agentInfo == nil)

        let session = try JSONDecoder().decode(
            ACPNewSessionRequest.self,
            from: Data(
                #"{"cwd":"/tmp","mcpServers":[],"additionalDirectories":["/one",4]}"#.utf8
            )
        )
        #expect(session.mcpServers.isEmpty)
        #expect(session.additionalDirectories == ["/one"])

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(
                ACPNewSessionRequest.self,
                from: Data(#"{"cwd":"/tmp"}"#.utf8)
            )
        }

        let update = try JSONDecoder().decode(
            ACPSessionUpdate.self,
            from: Data(
                #"{"sessionUpdate":"tool_call_update","toolCallId":"tool-1","title":4,"content":[{"type":"terminal","terminalId":"terminal-1"},{"type":"invalid"}]}"#
                    .utf8
            )
        )
        #expect(
            update
                == .toolCallUpdate(
                    ACPToolCallUpdate(
                        toolCallID: "tool-1",
                        content: .value([
                            .terminal(ACPTerminalToolCallContent(terminalID: "terminal-1"))
                        ])
                    )
                )
        )

        let toolCall = try JSONDecoder().decode(
            ACPToolCall.self,
            from: Data(
                #"{"toolCallId":"tool-2","title":"Future tool","kind":"future_kind","status":4}"#.utf8
            )
        )
        #expect(toolCall.kind == nil)
        #expect(toolCall.status == nil)
    }
}
