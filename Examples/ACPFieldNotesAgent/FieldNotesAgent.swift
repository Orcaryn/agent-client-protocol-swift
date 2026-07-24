import ACP
import ACPModel
import Foundation

@main
enum FieldNotesAgent {
    static func main() async throws {
        let server = ACPAgentServer(
            handlers: ACPAgentServerHandlers(
                lifecycle: ACPAgentLifecycleHandlers(
                    initialize: { _, request in
                        ACPInitializeResponse(
                            protocolVersion: request.protocolVersion,
                            agentInfo: ACPImplementationInfo(
                                name: "acp-field-notes-agent",
                                title: "Field Notes Agent",
                                version: "1.0.0"
                            )
                        )
                    }
                ),
                sessions: ACPAgentSessionHandlers(
                    new: { _, _ in
                        ACPNewSessionResponse(sessionID: UUID().uuidString)
                    },
                    prompt: { context, request in
                        let prompt = request.prompt.compactMap(text).joined(separator: " ")
                        let words = prompt.split(whereSeparator: \.isWhitespace)
                        let preview = words.prefix(12).joined(separator: " ")
                        let cwd = try await context.workingDirectory(sessionID: request.sessionID)

                        try await context.sessionUpdate(
                            ACPSessionNotification(
                                sessionID: request.sessionID,
                                update: .plan(
                                    ACPPlan(entries: [
                                        ACPPlanEntry(
                                            content: "Inspect the prompt",
                                            priority: .high,
                                            status: .completed
                                        ),
                                        ACPPlanEntry(
                                            content: "Write a compact field note",
                                            priority: .medium,
                                            status: .inProgress
                                        ),
                                    ])
                                )
                            )
                        )

                        try await context.sessionUpdate(
                            ACPSessionNotification(
                                sessionID: request.sessionID,
                                update: .agentThoughtChunk(
                                    ACPContentChunk(
                                        content: .text(
                                            ACPTextContent(
                                                text: "Distilling \(words.count) words into a scan-friendly note")
                                        )
                                    )
                                )
                            )
                        )

                        let note = """
                            Field note
                            • Prompt size: \(words.count) words
                            • Preview: \(preview.isEmpty ? "(no text supplied)" : preview)
                            • Workspace: \(cwd)
                            """

                        for chunk in noteChunks(note) {
                            try Task.checkCancellation()
                            try await context.sessionUpdate(
                                ACPSessionNotification(
                                    sessionID: request.sessionID,
                                    update: .agentMessageChunk(
                                        ACPContentChunk(content: .text(ACPTextContent(text: chunk)))
                                    )
                                )
                            )
                            try await Task.sleep(for: .milliseconds(35))
                        }

                        try await context.sessionUpdate(
                            ACPSessionNotification(
                                sessionID: request.sessionID,
                                update: .plan(
                                    ACPPlan(entries: [
                                        ACPPlanEntry(
                                            content: "Inspect the prompt",
                                            priority: .high,
                                            status: .completed
                                        ),
                                        ACPPlanEntry(
                                            content: "Write a compact field note",
                                            priority: .medium,
                                            status: .completed
                                        ),
                                    ])
                                )
                            )
                        )
                        try await context.sessionUpdate(
                            ACPSessionNotification(
                                sessionID: request.sessionID,
                                update: .usageUpdate(
                                    ACPUsageUpdate(
                                        used: UInt64(words.count),
                                        size: 4_096,
                                        // This agent does not invoke a model. Mark the sample value so
                                        // clients do not mistake it for tokenizer-reported usage.
                                        _meta: ["example": .string("synthetic")]
                                    )
                                )
                            )
                        )

                        return ACPPromptResponse(stopReason: .endTurn)
                    }
                )
            )
        )

        _ = try await server.run()
    }

    private static func text(from content: ACPContentBlock) -> String? {
        guard case .text(let text) = content else { return nil }
        return text.text
    }

    private static func noteChunks(_ note: String) -> [String] {
        note.split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .map { index, line in
                index == 0 ? String(line) : "\n\(line)"
            }
    }
}
