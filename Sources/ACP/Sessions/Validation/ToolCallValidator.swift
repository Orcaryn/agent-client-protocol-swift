import ACPModel

enum ToolCallValidator {
    static func validate(_ toolCall: ACPToolCall) throws {
        try validate(content: toolCall.content)
        for location in toolCall.locations ?? [] {
            try WorkspacePathPolicy.requireAbsolute(location.path)
            try SourceLocationValidator.requireOneBased(location.line)
        }
    }

    static func validate(_ update: ACPToolCallUpdate) throws {
        if case .value(let content) = update.content {
            try validate(content: content)
        }
        if case .value(let locations) = update.locations {
            for location in locations {
                try WorkspacePathPolicy.requireAbsolute(location.path)
                try SourceLocationValidator.requireOneBased(location.line)
            }
        }
    }

    static func validate(_ update: ACPSessionUpdate) throws {
        switch update {
        case .toolCall(let call):
            try validate(call)
        case .toolCallUpdate(let call):
            try validate(call)
        default:
            break
        }
    }

    private static func validate(content: [ACPToolCallContent]?) throws {
        for content in content ?? [] {
            if case .diff(let diff) = content {
                try WorkspacePathPolicy.requireAbsolute(diff.path)
            }
        }
    }
}
