import Testing

@testable import ACP
import ACPModel

extension ACPAgentServerTests {
    @Test func routesEveryStableAgentOperation() async throws {
        let routes = AgentServerRoutes()
        let transport = ScriptedAgentTransport(expectedResponseCount: 14)
        let server = ACPAgentServer(
            transport: transport,
            handlers: ACPAgentServerHandlers(
                lifecycle: ACPAgentLifecycleHandlers(
                    initialize: { _, request in
                        await routes.record("initialize:\(request.protocolVersion)")
                        return ACPInitializeResponse(
                            protocolVersion: request.protocolVersion,
                            agentCapabilities: ACPAgentCapabilities(
                                loadSession: true,
                                sessionCapabilities: ACPSessionCapabilities(
                                    list: ACPCapability(),
                                    delete: ACPCapability(),
                                    resume: ACPCapability(),
                                    close: ACPCapability()
                                ),
                                auth: ACPAgentAuthCapabilities(logout: ACPCapability())
                            ),
                            authMethods: [ACPAuthMethod(id: "token", name: "Token")]
                        )
                    },
                    authenticate: { _, request in
                        await routes.record("authenticate:\(request.methodID)")
                        return ACPAuthenticateResponse()
                    },
                    logout: { _, _ in
                        await routes.record("logout")
                        return ACPLogoutResponse()
                    }
                ),
                sessions: ACPAgentSessionHandlers(
                    new: { _, request in
                        await routes.record("new:\(request.cwd)")
                        return ACPNewSessionResponse(
                            sessionID: "new-session",
                            modes: ACPSessionModeState(
                                currentModeID: "review",
                                availableModes: [
                                    ACPSessionMode(id: "review", name: "Review")
                                ]
                            ),
                            configOptions: [
                                .boolean(
                                    ACPSessionConfigBoolean(
                                        id: "thinking",
                                        name: "Thinking",
                                        currentValue: false
                                    )
                                )
                            ]
                        )
                    },
                    prompt: { _, request in
                        await routes.record("prompt:\(request.sessionID)")
                        return ACPPromptResponse(stopReason: .endTurn)
                    },
                    load: { _, request in
                        await routes.record("load:\(request.sessionID)")
                        return ACPLoadSessionResponse()
                    },
                    resume: { _, request in
                        await routes.record("resume:\(request.sessionID)")
                        return ACPResumeSessionResponse()
                    },
                    list: { _, request in
                        await routes.record("list:\(request.cursor ?? "")")
                        return ACPListSessionsResponse(sessions: [])
                    },
                    delete: { _, request in
                        await routes.record("delete:\(request.sessionID)")
                        return ACPEmptyResponse()
                    },
                    close: { _, request in
                        await routes.record("close:\(request.sessionID)")
                        return ACPEmptyResponse()
                    },
                    setMode: { _, request in
                        await routes.record("mode:\(request.modeID)")
                        return ACPEmptyResponse()
                    },
                    setConfigOption: { _, request in
                        await routes.record("config:\(request.configID)")
                        return ACPSetConfigOptionResponse(configOptions: [])
                    },
                    cancel: { _, notification in
                        await routes.record("cancel:\(notification.sessionID)")
                    }
                ),
                extensions: ACPAgentExtensionHandlers(
                    request: { _, _, params in
                        await routes.record(params == nil ? "extension:absent" : "extension:null")
                        return .null
                    },
                    notification: { _, _, params in
                        await routes.record(params == nil ? "notification:absent" : "notification:null")
                    }
                )
            )
        )

        let run = Task {
            try await server.run()
        }
        await transport.waitUntilStarted()

        let requests: [ACPJSONRPCMessage] = [
            try request(
                1,
                ACPProtocol.Method.initialize,
                ACPInitializeRequest(
                    clientCapabilities: ACPClientCapabilities(
                        session: ACPClientSessionCapabilities(
                            configOptions: ACPSessionConfigOptionsCapabilities(
                                boolean: ACPBooleanConfigOptionCapabilities()
                            )
                        )
                    )
                )
            ),
            try request(2, ACPProtocol.Method.authenticate, ACPAuthenticateRequest(methodID: "token")),
            try request(3, ACPProtocol.Method.logout, ACPLogoutRequest()),
            try request(4, ACPProtocol.Method.sessionNew, ACPNewSessionRequest(cwd: "/tmp/new")),
            try request(
                5,
                ACPProtocol.Method.sessionLoad,
                ACPLoadSessionRequest(sessionID: "load-session", cwd: "/tmp/load")
            ),
            try request(
                6,
                ACPProtocol.Method.sessionResume,
                ACPResumeSessionRequest(sessionID: "resume-session", cwd: "/tmp/resume")
            ),
            try request(7, ACPProtocol.Method.sessionList, ACPListSessionsRequest(cursor: "next")),
            try request(8, ACPProtocol.Method.sessionDelete, ACPSessionIDRequest(sessionID: "delete-session")),
            try request(9, ACPProtocol.Method.sessionClose, ACPSessionIDRequest(sessionID: "load-session")),
            try request(
                10,
                ACPProtocol.Method.sessionPrompt,
                ACPPromptRequest(
                    sessionID: "new-session",
                    prompt: [.text(ACPTextContent(text: "hello"))]
                )
            ),
            .request(id: .integer(13), method: "_test/absent", params: nil),
            .request(id: .integer(14), method: "_test/null", params: .null),
            try request(
                11,
                ACPProtocol.Method.sessionSetMode,
                ACPSetSessionModeRequest(sessionID: "new-session", modeID: "review")
            ),
            try request(
                12,
                ACPProtocol.Method.sessionSetConfigOption,
                ACPSetConfigOptionRequest(
                    sessionID: "new-session",
                    configID: "thinking",
                    value: .boolean(true)
                )
            ),
        ]

        for (index, message) in requests.enumerated() {
            await transport.receive(message)
            while await transport.sentMessages().count < index + 1 {
                await Task.yield()
            }
            if index == 0 {
                await transport.receive(.notification(method: "_test/absent", params: nil))
                await transport.receive(.notification(method: "_test/null", params: .null))
            }
            if index == 3 {
                await transport.receive(
                    try notification(
                        method: ACPProtocol.Method.sessionCancel,
                        params: ACPCancelSessionNotification(sessionID: "new-session")
                    )
                )
            }
        }

        #expect(try await run.value == .endOfFile)
        let sentMessages = await transport.sentMessages()
        #expect(sentMessages.count == requests.count)
        #expect(
            sentMessages.allSatisfy { message in
                if case .response = message {
                    return true
                }
                Issue.record("Unexpected server message: \(message)")
                return false
            })
        #expect(
            await routes.snapshot() == [
                "initialize:1",
                "authenticate:token",
                "logout",
                "new:/tmp/new",
                "load:load-session",
                "resume:resume-session",
                "list:next",
                "delete:delete-session",
                "close:load-session",
                "prompt:new-session",
                "mode:review",
                "config:thinking",
                "cancel:new-session",
                "extension:absent",
                "extension:null",
                "notification:absent",
                "notification:null",
            ])
    }
    @Test func malformedKnownRequestReturnsInvalidParamsWithoutCallingHandler() async throws {
        let routes = AgentServerRoutes()
        let transport = ScriptedAgentTransport(expectedResponseCount: 2)
        let server = ACPAgentServer(
            transport: transport,
            handlers: ACPAgentServerHandlers(
                lifecycle: ACPAgentLifecycleHandlers(
                    initialize: { _, request in
                        await routes.record("initialize")
                        return ACPInitializeResponse(protocolVersion: request.protocolVersion)
                    }
                ),
                sessions: ACPAgentSessionHandlers(
                    new: { _, _ in
                        await routes.record("new-session")
                        return ACPNewSessionResponse(sessionID: "unexpected")
                    },
                    prompt: { _, _ in
                        await routes.record("prompt")
                        return ACPPromptResponse(stopReason: .endTurn)
                    }
                )
            )
        )

        let run = Task { try await server.run() }
        await transport.waitUntilStarted()
        await transport.receive(
            try request(40, ACPProtocol.Method.initialize, ACPInitializeRequest())
        )
        while await transport.sentMessages().isEmpty {
            await Task.yield()
        }
        await transport.receive(
            .request(
                id: .integer(41),
                method: ACPProtocol.Method.sessionNew,
                params: .object([
                    "cwd": .integer(7),
                    "mcpServers": .array([]),
                ])
            )
        )

        #expect(try await run.value == .endOfFile)
        #expect(await routes.snapshot() == ["initialize"])
        guard case .error(let id, let error) = await transport.sentMessages().last else {
            Issue.record("Expected invalid-params response")
            return
        }
        #expect(id == .integer(41))
        #expect(error == .invalidParams)
    }
    @Test func missingParamsAndUnknownMethodsReturnProtocolErrors() async throws {
        let transport = ScriptedAgentTransport(expectedResponseCount: 3)
        let server = ACPAgentServer(
            transport: transport,
            handlers: ACPAgentServerHandlers(
                lifecycle: ACPAgentLifecycleHandlers(
                    initialize: { _, request in
                        ACPInitializeResponse(protocolVersion: request.protocolVersion)
                    }
                ),
                sessions: ACPAgentSessionHandlers(
                    new: { _, _ in ACPNewSessionResponse(sessionID: "unused") },
                    prompt: { _, _ in ACPPromptResponse(stopReason: .endTurn) }
                )
            )
        )

        let run = Task { try await server.run() }
        await transport.waitUntilStarted()
        await transport.receive(
            try request(0, ACPProtocol.Method.initialize, ACPInitializeRequest())
        )
        while await transport.sentMessages().isEmpty {
            await Task.yield()
        }
        await transport.receive(
            .request(id: .integer(1), method: ACPProtocol.Method.sessionPrompt, params: nil)
        )
        await transport.receive(
            .request(id: .integer(2), method: "session/not_a_method", params: .object([:]))
        )

        #expect(try await run.value == .endOfFile)
        let messages = await transport.sentMessages()
        let errorPairs: [(ACPRequestID, ACPJSONRPCError)] = messages.compactMap { message in
            guard case .error(let id, let error) = message else { return nil }
            return (id, error)
        }
        let errors = Dictionary(uniqueKeysWithValues: errorPairs)
        guard let missingParamsError = errors[.integer(1)],
            let unknownMethodError = errors[.integer(2)]
        else {
            Issue.record("Expected JSON-RPC errors for both requests")
            return
        }
        #expect(missingParamsError == .invalidParams)
        #expect(unknownMethodError == .methodNotFound)
    }
}
