import ACPModel

enum ContentCapabilityValidator {
    static func validate(
        _ prompt: [ACPContentBlock],
        capabilities: ACPPromptCapabilities
    ) throws {
        for content in prompt {
            switch content {
            case .image where !capabilities.image,
                .audio where !capabilities.audio,
                .resource where !capabilities.embeddedContext:
                throw ACPJSONRPCError.invalidParams
            default:
                break
            }
        }
    }
}
