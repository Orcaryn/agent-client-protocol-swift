import Foundation

public enum ACPSessionUpdate: Equatable, Sendable {
    case userMessageChunk(ACPContentChunk)
    case agentMessageChunk(ACPContentChunk)
    case agentThoughtChunk(ACPContentChunk)
    case toolCall(ACPToolCall)
    case toolCallUpdate(ACPToolCallUpdate)
    case plan(ACPPlan)
    case availableCommandsUpdate(ACPAvailableCommandsUpdate)
    case currentModeUpdate(ACPCurrentModeUpdate)
    case configOptionUpdate(ACPConfigOptionUpdate)
    case sessionInfoUpdate(ACPSessionInfoUpdate)
    case usageUpdate(ACPUsageUpdate)
}

extension ACPSessionUpdate: Codable {
    public init(from decoder: Decoder) throws {
        switch try ACPTaggedCoding.tag("sessionUpdate", from: decoder) {
        case "user_message_chunk":
            self = .userMessageChunk(try ACPContentChunk(from: decoder))
        case "agent_message_chunk":
            self = .agentMessageChunk(try ACPContentChunk(from: decoder))
        case "agent_thought_chunk":
            self = .agentThoughtChunk(try ACPContentChunk(from: decoder))
        case "tool_call":
            self = .toolCall(try ACPToolCall(from: decoder))
        case "tool_call_update":
            self = .toolCallUpdate(try ACPToolCallUpdate(from: decoder))
        case "plan":
            self = .plan(try ACPPlan(from: decoder))
        case "available_commands_update":
            self = .availableCommandsUpdate(try ACPAvailableCommandsUpdate(from: decoder))
        case "current_mode_update":
            self = .currentModeUpdate(try ACPCurrentModeUpdate(from: decoder))
        case "config_option_update":
            self = .configOptionUpdate(try ACPConfigOptionUpdate(from: decoder))
        case "session_info_update":
            self = .sessionInfoUpdate(try ACPSessionInfoUpdate(from: decoder))
        case "usage_update":
            self = .usageUpdate(try ACPUsageUpdate(from: decoder))
        default:
            throw ACPJSONRPCError.invalidParams
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .userMessageChunk(let update):
            try ACPTaggedCoding.encode(update, tag: "user_message_chunk", key: "sessionUpdate", to: encoder)
        case .agentMessageChunk(let update):
            try ACPTaggedCoding.encode(update, tag: "agent_message_chunk", key: "sessionUpdate", to: encoder)
        case .agentThoughtChunk(let update):
            try ACPTaggedCoding.encode(update, tag: "agent_thought_chunk", key: "sessionUpdate", to: encoder)
        case .toolCall(let update):
            try ACPTaggedCoding.encode(update, tag: "tool_call", key: "sessionUpdate", to: encoder)
        case .toolCallUpdate(let update):
            try ACPTaggedCoding.encode(update, tag: "tool_call_update", key: "sessionUpdate", to: encoder)
        case .plan(let update):
            try ACPTaggedCoding.encode(update, tag: "plan", key: "sessionUpdate", to: encoder)
        case .availableCommandsUpdate(let update):
            try ACPTaggedCoding.encode(update, tag: "available_commands_update", key: "sessionUpdate", to: encoder)
        case .currentModeUpdate(let update):
            try ACPTaggedCoding.encode(update, tag: "current_mode_update", key: "sessionUpdate", to: encoder)
        case .configOptionUpdate(let update):
            try ACPTaggedCoding.encode(update, tag: "config_option_update", key: "sessionUpdate", to: encoder)
        case .sessionInfoUpdate(let update):
            try ACPTaggedCoding.encode(update, tag: "session_info_update", key: "sessionUpdate", to: encoder)
        case .usageUpdate(let update):
            try ACPTaggedCoding.encode(update, tag: "usage_update", key: "sessionUpdate", to: encoder)
        }
    }
}

public struct ACPSessionNotification: Codable, Equatable, Sendable {
    public let sessionID: String
    public let update: ACPSessionUpdate
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(sessionID: String, update: ACPSessionUpdate, _meta: ACPMeta? = nil) {
        self.sessionID = sessionID
        self.update = update
        self._meta = _meta
    }

    private enum CodingKeys: String, CodingKey {
        case sessionID = "sessionId"
        case update, _meta
    }
}
