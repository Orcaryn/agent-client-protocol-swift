import Foundation
import Testing

@testable import ACPModel

struct ACPSchemaBaselineTests {
    @Test func protocolMethodsMatchPinnedStableSchema() throws {
        let definitions = try schemaDefinitions()
        let schemaMethods = Set(
            definitions.values.compactMap { definition in
                (definition as? [String: Any])?["x-method"] as? String
            })

        #expect(
            schemaMethods
                == Set([
                    ACPProtocol.Method.initialize,
                    ACPProtocol.Method.authenticate,
                    ACPProtocol.Method.logout,
                    ACPProtocol.Method.sessionNew,
                    ACPProtocol.Method.sessionLoad,
                    ACPProtocol.Method.sessionResume,
                    ACPProtocol.Method.sessionList,
                    ACPProtocol.Method.sessionDelete,
                    ACPProtocol.Method.sessionClose,
                    ACPProtocol.Method.sessionPrompt,
                    ACPProtocol.Method.sessionCancel,
                    ACPProtocol.Method.sessionSetMode,
                    ACPProtocol.Method.sessionSetConfigOption,
                    ACPProtocol.Method.sessionUpdate,
                    ACPProtocol.Method.sessionRequestPermission,
                    ACPProtocol.Method.fileSystemReadTextFile,
                    ACPProtocol.Method.fileSystemWriteTextFile,
                    ACPProtocol.Method.terminalCreate,
                    ACPProtocol.Method.terminalOutput,
                    ACPProtocol.Method.terminalWaitForExit,
                    ACPProtocol.Method.terminalKill,
                    ACPProtocol.Method.terminalRelease,
                    ACPProtocol.Method.cancelRequest,
                ]))
    }

    @Test func sessionUpdateVariantsMatchPinnedStableSchema() throws {
        let definitions = try schemaDefinitions()
        let sessionUpdate = try #require(definitions["SessionUpdate"] as? [String: Any])
        let variants = try #require(sessionUpdate["oneOf"] as? [[String: Any]])
        let schemaTags = Set(
            variants.compactMap { variant -> String? in
                let properties = variant["properties"] as? [String: Any]
                let tag = properties?["sessionUpdate"] as? [String: Any]
                return tag?["const"] as? String
            })

        #expect(
            schemaTags
                == Set([
                    "user_message_chunk",
                    "agent_message_chunk",
                    "agent_thought_chunk",
                    "tool_call",
                    "tool_call_update",
                    "plan",
                    "available_commands_update",
                    "current_mode_update",
                    "config_option_update",
                    "session_info_update",
                    "usage_update",
                ]))
    }

    @Test func configCategoryConstantsMatchPinnedStableSchema() throws {
        let definitions = try schemaDefinitions()
        let category = try #require(
            definitions["SessionConfigOptionCategory"] as? [String: Any]
        )
        let variants = try #require(category["anyOf"] as? [[String: Any]])
        let schemaConstants = Set(variants.compactMap { $0["const"] as? String })

        #expect(
            schemaConstants
                == Set([
                    ACPSessionConfigOptionCategory.mode.rawValue,
                    ACPSessionConfigOptionCategory.model.rawValue,
                    ACPSessionConfigOptionCategory.modelConfig.rawValue,
                    ACPSessionConfigOptionCategory.thoughtLevel.rawValue,
                ]))
    }

    private func schemaDefinitions() throws -> [String: Any] {
        let url = try #require(
            Bundle.module.url(
                forResource: "acp-v1.19.0-schema",
                withExtension: "json"
            )
        )
        let data = try Data(contentsOf: url)
        let schema = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        #expect(schema["title"] as? String == "Agent Client Protocol")
        return try #require(schema["$defs"] as? [String: Any])
    }
}
