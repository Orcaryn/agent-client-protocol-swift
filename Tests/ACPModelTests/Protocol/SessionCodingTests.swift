import Foundation
import Testing

@testable import ACPModel

struct SessionCodingTests {
    @Test func configurationCategoriesPreserveStandardAndCustomValues() throws {
        #expect(ACPSessionConfigOptionCategory.mode.rawValue == "mode")
        #expect(ACPSessionConfigOptionCategory.model.rawValue == "model")
        #expect(ACPSessionConfigOptionCategory.modelConfig.rawValue == "model_config")
        #expect(ACPSessionConfigOptionCategory.thoughtLevel.rawValue == "thought_level")

        let standard = ACPSessionConfigBoolean(
            id: "thinking",
            name: "Thinking",
            currentValue: true,
            category: .thoughtLevel
        )
        try expectCanonicalJSON(
            standard,
            #"{"id":"thinking","name":"Thinking","category":"thought_level","currentValue":true}"#
        )

        let custom = try decode(
            ACPSessionConfigBoolean.self,
            #"{"id":"vendor","name":"Vendor","category":"_vendor_custom","currentValue":false}"#
        )
        #expect(custom.category?.rawValue == "_vendor_custom")

        try expectCanonicalJSON(
            ACPSessionConfigBoolean(
                id: "vendor",
                name: "Vendor",
                currentValue: false,
                category: ACPSessionConfigOptionCategory(rawValue: "_vendor_custom")
            ),
            #"{"id":"vendor","name":"Vendor","category":"_vendor_custom","currentValue":false}"#
        )

        let malformed = try decode(
            ACPSessionConfigBoolean.self,
            #"{"id":"vendor","name":"Vendor","category":7,"currentValue":false}"#
        )
        #expect(malformed.category == nil)
    }

    @Test func toolCallDefaultsHaveEffectiveValues() {
        let call = ACPToolCall(toolCallID: "call", title: "Work")
        #expect(call.kind == nil)
        #expect(call.status == nil)
        #expect(call.effectiveKind == .other)
        #expect(call.effectiveStatus == .pending)
    }

    @Test func canonicalSessionUpdatesMatchWireSchema() throws {
        let chunk = ACPContentChunk(content: .text(ACPTextContent(text: "chunk")))
        try expectCanonicalJSON(
            .userMessageChunk(chunk) as ACPSessionUpdate,
            #"{"sessionUpdate":"user_message_chunk","content":{"type":"text","text":"chunk"}}"#
        )
        try expectCanonicalJSON(
            .agentMessageChunk(
                ACPContentChunk(
                    content: .text(ACPTextContent(text: "done")),
                    messageID: "message-1"
                )
            ) as ACPSessionUpdate,
            #"{"sessionUpdate":"agent_message_chunk","content":{"type":"text","text":"done"},"messageId":"message-1"}"#
        )
        try expectCanonicalJSON(
            .agentThoughtChunk(chunk) as ACPSessionUpdate,
            #"{"sessionUpdate":"agent_thought_chunk","content":{"type":"text","text":"chunk"}}"#
        )
        try expectCanonicalJSON(
            .toolCall(
                ACPToolCall(
                    toolCallID: "tool-1",
                    title: "Read file",
                    kind: .read,
                    status: .inProgress,
                    content: [.terminal(ACPTerminalToolCallContent(terminalID: "terminal-1"))],
                    locations: [ACPToolCallLocation(path: "/tmp/file", line: 4)],
                    rawInput: .object(["path": .string("/tmp/file")])
                )
            ) as ACPSessionUpdate,
            #"{"sessionUpdate":"tool_call","toolCallId":"tool-1","title":"Read file","kind":"read","status":"in_progress","content":[{"type":"terminal","terminalId":"terminal-1"}],"locations":[{"path":"/tmp/file","line":4}],"rawInput":{"path":"/tmp/file"}}"#
        )
        try expectCanonicalJSON(
            .toolCallUpdate(
                ACPToolCallUpdate(
                    toolCallID: "tool-1",
                    status: .value(.completed),
                    title: .null,
                    content: .value([
                        .diff(ACPDiffToolCallContent(path: "/tmp/file", oldText: "old", newText: "new"))
                    ])
                )
            ) as ACPSessionUpdate,
            #"{"sessionUpdate":"tool_call_update","toolCallId":"tool-1","status":"completed","title":null,"content":[{"type":"diff","path":"/tmp/file","oldText":"old","newText":"new"}]}"#
        )
        try expectCanonicalJSON(
            .plan(
                ACPPlan(entries: [ACPPlanEntry(content: "Ship", priority: .high, status: .inProgress)])
            ) as ACPSessionUpdate,
            #"{"sessionUpdate":"plan","entries":[{"content":"Ship","priority":"high","status":"in_progress"}]}"#
        )
        try expectCanonicalJSON(
            .availableCommandsUpdate(
                ACPAvailableCommandsUpdate(
                    availableCommands: [
                        ACPAvailableCommand(
                            name: "review",
                            description: "Review changes",
                            input: ACPAvailableCommandInput(hint: "path")
                        )
                    ]
                )
            ) as ACPSessionUpdate,
            #"{"sessionUpdate":"available_commands_update","availableCommands":[{"name":"review","description":"Review changes","input":{"hint":"path"}}]}"#
        )
        try expectCanonicalJSON(
            .currentModeUpdate(ACPCurrentModeUpdate(currentModeID: "code")) as ACPSessionUpdate,
            #"{"sessionUpdate":"current_mode_update","currentModeId":"code"}"#
        )
        try expectCanonicalJSON(
            .configOptionUpdate(
                ACPConfigOptionUpdate(
                    configOptions: [
                        .boolean(ACPSessionConfigBoolean(id: "thinking", name: "Thinking", currentValue: true))
                    ]
                )
            ) as ACPSessionUpdate,
            #"{"sessionUpdate":"config_option_update","configOptions":[{"type":"boolean","id":"thinking","name":"Thinking","currentValue":true}]}"#
        )
        try expectCanonicalJSON(
            .sessionInfoUpdate(
                ACPSessionInfoUpdate(title: .null, updatedAt: .value("2026-07-12T12:00:00Z"))
            ) as ACPSessionUpdate,
            #"{"sessionUpdate":"session_info_update","title":null,"updatedAt":"2026-07-12T12:00:00Z"}"#
        )
        try expectCanonicalJSON(
            .usageUpdate(ACPUsageUpdate(used: 10, size: 100, cost: ACPCost(amount: 0.01, currency: "USD")))
                as ACPSessionUpdate,
            #"{"sessionUpdate":"usage_update","used":10,"size":100,"cost":{"amount":0.01,"currency":"USD"}}"#
        )
    }

    @Test func canonicalConfigurationAndMCPServersMatchWireSchema() throws {
        try expectCanonicalJSON(
            .select(
                ACPSessionConfigSelect(
                    id: "model",
                    name: "Model",
                    currentValue: "fast",
                    options: .ungrouped([
                        ACPSessionConfigSelectOption(value: "fast", name: "Fast")
                    ])
                )
            ) as ACPSessionConfigOption,
            #"{"type":"select","id":"model","name":"Model","currentValue":"fast","options":[{"value":"fast","name":"Fast"}]}"#
        )
        try expectCanonicalJSON(
            .select(
                ACPSessionConfigSelect(
                    id: "model",
                    name: "Model",
                    currentValue: "smart",
                    options: .grouped([
                        ACPSessionConfigSelectGroup(
                            group: "quality",
                            name: "Quality",
                            options: [ACPSessionConfigSelectOption(value: "smart", name: "Smart")]
                        )
                    ]),
                    description: "Active model"
                )
            ) as ACPSessionConfigOption,
            #"{"type":"select","id":"model","name":"Model","description":"Active model","currentValue":"smart","options":[{"group":"quality","name":"Quality","options":[{"value":"smart","name":"Smart"}]}]}"#
        )
        try expectCanonicalJSON(
            .boolean(ACPSessionConfigBoolean(id: "thinking", name: "Thinking", currentValue: true))
                as ACPSessionConfigOption,
            #"{"type":"boolean","id":"thinking","name":"Thinking","currentValue":true}"#
        )
        try expectCanonicalJSON(
            .http(
                ACPMCPHTTPServer(
                    name: "Remote",
                    url: "https://example.com/mcp",
                    headers: [ACPHTTPHeader(name: "Authorization", value: "Bearer token")]
                )
            ) as ACPMCPServer,
            #"{"type":"http","name":"Remote","url":"https://example.com/mcp","headers":[{"name":"Authorization","value":"Bearer token"}]}"#
        )
        try expectCanonicalJSON(
            .sse(ACPMCPSSEServer(name: "Events", url: "https://example.com/sse", headers: [])) as ACPMCPServer,
            #"{"type":"sse","name":"Events","url":"https://example.com/sse","headers":[]}"#
        )
        try expectCanonicalJSON(
            .stdio(
                ACPMCPStdioServer(
                    name: "Local",
                    command: "/usr/bin/mcp",
                    args: ["--stdio"],
                    env: [ACPEnvironmentVariable(name: "MODE", value: "test")]
                )
            ) as ACPMCPServer,
            #"{"name":"Local","command":"/usr/bin/mcp","args":["--stdio"],"env":[{"name":"MODE","value":"test"}]}"#
        )
    }

    @Test func canonicalLifecyclePayloadMatchesWireSchema() throws {
        try expectCanonicalJSON(
            ACPNewSessionRequest(
                cwd: "/workspace",
                additionalDirectories: ["/shared"],
                mcpServers: [
                    .stdio(ACPMCPStdioServer(name: "Local", command: "mcp", args: [], env: []))
                ],
                _meta: ["requestId": .integer(7)]
            ),
            #"{"cwd":"/workspace","additionalDirectories":["/shared"],"mcpServers":[{"name":"Local","command":"mcp","args":[],"env":[]}],"_meta":{"requestId":7}}"#
        )
        try expectCanonicalJSON(
            ACPPromptResponse(stopReason: .maxTurnRequests),
            #"{"stopReason":"max_turn_requests"}"#
        )
        try expectCanonicalJSON(
            ACPSetConfigOptionRequest(
                sessionID: "session-1",
                configID: "thinking",
                value: .boolean(true)
            ),
            #"{"sessionId":"session-1","configId":"thinking","type":"boolean","value":true}"#
        )
        try expectCanonicalJSON(
            ACPSetConfigOptionRequest(
                sessionID: "session-1",
                configID: "model",
                value: .valueID("smart")
            ),
            #"{"sessionId":"session-1","configId":"model","value":"smart"}"#
        )
        try expectCanonicalJSON(
            ACPRequestPermissionResponse(outcome: .cancelled),
            #"{"outcome":{"outcome":"cancelled"}}"#
        )
        try expectCanonicalJSON(
            ACPRequestPermissionResponse(
                outcome: .selected(
                    optionID: "allow-once",
                    _meta: ["source": .string("test")]
                )
            ),
            #"{"outcome":{"outcome":"selected","optionId":"allow-once","_meta":{"source":"test"}}}"#
        )
    }
}
