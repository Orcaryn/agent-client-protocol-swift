import ACP
import ACPModel
import ACPProcess
import Foundation

@main
enum TrailCommand {
    static func main() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard let executablePath = arguments.first else {
            print("Usage: acp-trail <agent-executable> [agent-arguments ... --] [prompt]")
            print("Example: acp-trail .build/debug/acp-field-notes-agent \"Summarize this request\"")
            return
        }

        let remainingArguments = Array(arguments.dropFirst())
        let agentArguments: [String]
        let promptArguments: [String]
        if let separatorIndex = remainingArguments.firstIndex(of: "--") {
            agentArguments = Array(remainingArguments[..<separatorIndex])
            promptArguments = Array(remainingArguments[(separatorIndex + 1)...])
        } else {
            agentArguments = []
            promptArguments = remainingArguments
        }

        let prompt = promptArguments.joined(separator: " ")
        let promptText = prompt.isEmpty ? "Give me a short orientation to this workspace." : prompt
        let executableURL = URL(fileURLWithPath: executablePath).standardizedFileURL

        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw TrailError.agentIsNotExecutable(executableURL.path)
        }

        let transcript = TrailTranscript()
        let client = ACPAgentClient(
            launch: ACPProcessLaunch(executableURL: executableURL, arguments: agentArguments),
            clientInfo: ACPImplementationInfo(
                name: "acp-trail",
                title: "ACP Trail",
                version: "1.0.0"
            )
        )
        let events = await client.events(bufferingNewest: 200)
        let eventPump = Task {
            for await event in events {
                switch event {
                case .sessionUpdate(let update):
                    await transcript.receive(update)
                case .log(let line):
                    await transcript.log(line)
                case .terminated(let reason):
                    await transcript.terminated(reason)
                case .wire:
                    break
                case .overflow:
                    await transcript.log("Event stream overflowed; some events were not delivered")
                }
            }
        }

        do {
            let initialization = try await client.connect()
            await transcript.connected(to: initialization.agentInfo)

            let session = try await client.newSession(
                cwd: FileManager.default.currentDirectoryPath
            )
            await transcript.started(sessionID: session.sessionID, prompt: promptText)

            let response = try await client.prompt(
                sessionID: session.sessionID,
                content: [.text(ACPTextContent(text: promptText))]
            )
            await transcript.finished(reason: response.stopReason)
            await client.shutdown()
            await eventPump.value
        } catch {
            eventPump.cancel()
            await client.shutdown()
            await eventPump.value
            throw error
        }
    }
}

private enum TrailError: LocalizedError {
    case agentIsNotExecutable(String)

    var errorDescription: String? {
        switch self {
        case .agentIsNotExecutable(let path):
            "No executable ACP agent was found at \(path)"
        }
    }
}

private actor TrailTranscript {
    private var messageLineIsOpen = false

    func connected(to agent: ACPImplementationInfo?) {
        let label = agent?.title ?? agent?.name ?? "ACP agent"
        let version = agent.map { " v\($0.version)" } ?? ""
        print("Connected to \(label)\(version)")
    }

    func started(sessionID: String, prompt: String) {
        print("Session \(sessionID)")
        print("You: \(prompt)")
    }

    func receive(_ notification: ACPSessionNotification) {
        switch notification.update {
        case .agentMessageChunk(let chunk):
            if let text = text(from: chunk.content) {
                if !messageLineIsOpen {
                    print("Agent: ", terminator: "")
                }
                print(text, terminator: "")
                messageLineIsOpen = true
            }

        case .agentThoughtChunk(let chunk):
            lineBreakIfNeeded()
            if let text = text(from: chunk.content) {
                print("  thought: \(text)")
            }

        case .userMessageChunk(let chunk):
            lineBreakIfNeeded()
            if let text = text(from: chunk.content) {
                print("  user update: \(text)")
            }

        case .plan(let plan):
            lineBreakIfNeeded()
            print("  plan:")
            for entry in plan.entries {
                print("    [\(entry.status.rawValue)] \(entry.content)")
            }

        case .toolCall(let call):
            lineBreakIfNeeded()
            print("  tool \(call.toolCallID): \(call.title) [\(call.effectiveStatus.rawValue)]")

        case .toolCallUpdate(let update):
            lineBreakIfNeeded()
            let status: String
            switch update.status {
            case .value(let value): status = value.rawValue
            case .null: status = "cleared"
            case .absent: status = "updated"
            }
            print("  tool \(update.toolCallID): \(status)")

        case .usageUpdate(let usage):
            lineBreakIfNeeded()
            let qualifier = usage._meta?["example"] == .string("synthetic") ? " (synthetic)" : ""
            print("  context\(qualifier): \(usage.used)/\(usage.size)")

        case .availableCommandsUpdate(let update):
            lineBreakIfNeeded()
            let names = update.availableCommands.map(\.name).joined(separator: ", ")
            print("  commands: \(names)")

        case .currentModeUpdate(let update):
            lineBreakIfNeeded()
            print("  mode: \(update.currentModeID)")

        case .configOptionUpdate(let update):
            lineBreakIfNeeded()
            print("  configuration changed (\(update.configOptions.count) options)")

        case .sessionInfoUpdate:
            lineBreakIfNeeded()
            print("  session metadata changed")
        }
    }

    func log(_ line: String) {
        lineBreakIfNeeded()
        print("  agent log: \(line)")
    }

    func terminated(_ reason: ACPTransportTermination) {
        lineBreakIfNeeded()
        switch reason {
        case .endOfFile:
            print("Connection closed (end of file)")
        case .terminated:
            print("Connection closed")
        case .processExited(let status):
            print("Agent exited with status \(status)")
        case .invalidMessage(let detail):
            print("Connection closed: invalid ACP message (\(detail))")
        }
    }

    func finished(reason: ACPStopReason) {
        lineBreakIfNeeded()
        print("Turn finished: \(reason.rawValue)")
    }

    private func lineBreakIfNeeded() {
        guard messageLineIsOpen else { return }
        print()
        messageLineIsOpen = false
    }

    private func text(from content: ACPContentBlock) -> String? {
        guard case .text(let text) = content else { return nil }
        return text.text
    }
}
