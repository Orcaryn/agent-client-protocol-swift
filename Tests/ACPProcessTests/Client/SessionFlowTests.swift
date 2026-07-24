import ACPTestSupport
import Darwin
import Foundation
import Testing

@testable import ACP
import ACPModel
import ACPProcess

extension ACPAgentClientProcessTests {
    @Test func createsConfiguresPromptsAndLoadsSession() async throws {
        let updates = SessionUpdates()
        let clientMethods = ClientMethodCalls()
        let client = makeClient(
            callbacks: ACPAgentClientCallbacks(
                session: ACPClientSessionCallbacks(
                    update: { update in
                        await updates.append(update)
                    },
                    permissionRequest: { request in
                        await clientMethods.record(ACPProtocol.Method.sessionRequestPermission)
                        return ACPRequestPermissionResponse(
                            outcome: .selected(optionID: request.options[0].optionID)
                        )
                    }
                ),
                fileSystem: ACPClientFileSystemCallbacks(
                    readTextFile: { _ in
                        await clientMethods.record(ACPProtocol.Method.fileSystemReadTextFile)
                        return ACPReadTextFileResponse(content: "input")
                    },
                    writeTextFile: { _ in
                        await clientMethods.record(ACPProtocol.Method.fileSystemWriteTextFile)
                        return ACPEmptyResponse()
                    }
                ),
                terminal: ACPClientTerminalCallbacks(
                    create: { _ in
                        await clientMethods.record(ACPProtocol.Method.terminalCreate)
                        return ACPCreateTerminalResponse(terminalID: "terminal-1")
                    },
                    output: { _ in
                        await clientMethods.record(ACPProtocol.Method.terminalOutput)
                        return ACPTerminalOutputResponse(output: "a🙂bcdef", truncated: false)
                    },
                    waitForExit: { _ in
                        await clientMethods.record(ACPProtocol.Method.terminalWaitForExit)
                        return ACPWaitForTerminalExitResponse(exitCode: 0)
                    },
                    kill: { _ in
                        await clientMethods.record(ACPProtocol.Method.terminalKill)
                        return ACPEmptyResponse()
                    },
                    release: { _ in
                        await clientMethods.record(ACPProtocol.Method.terminalRelease)
                        return ACPEmptyResponse()
                    }
                )
            )
        )

        let initialization = try await client.connect()
        #expect(initialization.protocolVersion == 1)

        let session = try await client.newSession(cwd: "/tmp")
        #expect(session.sessionID == "session-1")
        if case .select(let option) = session.configOptions?.first {
            #expect(option.currentValue == "model-1")
        } else {
            Issue.record("Expected a select config option")
        }

        await #expect(throws: ACPJSONRPCError.invalidParams) {
            try await client.setMode(sessionID: session.sessionID, modeID: "missing")
        }
        await #expect(throws: ACPJSONRPCError.invalidParams) {
            try await client.setConfigOption(
                sessionID: session.sessionID,
                configID: "model",
                value: .valueID("missing")
            )
        }
        await #expect(throws: ACPJSONRPCError.invalidParams) {
            try await client.setConfigOption(
                sessionID: session.sessionID,
                configID: "model",
                value: .boolean(true)
            )
        }

        let options = try await client.setConfigOption(
            sessionID: session.sessionID,
            configID: "model",
            value: .valueID("model-2")
        )
        if case .select(let option) = options.first {
            #expect(option.currentValue == "model-2")
        } else {
            Issue.record("Expected a select config option")
        }

        let prompt = try await client.prompt(
            sessionID: session.sessionID,
            content: [.text(ACPTextContent(text: "Hello"))]
        )
        #expect(prompt.stopReason == .endTurn)
        #expect(
            await eventually {
                await client.currentPlan(sessionID: session.sessionID)?.entries.map(\.content)
                    == ["replacement"]
            })

        _ = try await client.loadSession(sessionID: session.sessionID, cwd: "/tmp")
        _ = try await client.resumeSession(sessionID: session.sessionID, cwd: "/tmp")
        let listed = try await client.listSessions(cwd: "/tmp")
        #expect(listed.sessions.map(\.sessionID) == ["session-1"])
        #expect(listed.nextCursor == "next")
        try await client.setMode(sessionID: session.sessionID, modeID: "code")
        try await client.cancel(sessionID: session.sessionID)
        try await client.closeSession(sessionID: session.sessionID)
        try await client.deleteSession(sessionID: session.sessionID)
        try await client.authenticate(methodID: "test")
        try await client.logout()

        let received = await updates.values
        #expect(
            received.contains { update in
                if case .agentMessageChunk = update.update {
                    return true
                }
                return false
            })
        #expect(
            await clientMethods.methods == [
                ACPProtocol.Method.sessionRequestPermission,
                ACPProtocol.Method.fileSystemReadTextFile,
                ACPProtocol.Method.fileSystemWriteTextFile,
                ACPProtocol.Method.terminalCreate,
                ACPProtocol.Method.terminalOutput,
                ACPProtocol.Method.terminalWaitForExit,
                ACPProtocol.Method.terminalKill,
                ACPProtocol.Method.terminalRelease,
            ])
        #expect(
            received.contains { update in
                if case .userMessageChunk = update.update {
                    return true
                }
                return false
            })

        await client.shutdown()
    }
}
