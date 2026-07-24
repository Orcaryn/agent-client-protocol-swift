import ACPModel

import Foundation

actor SessionRegistry {
    enum Role: Equatable, Sendable {
        case client
        case agent
    }

    struct Setup: Sendable {
        fileprivate let token: UUID
        fileprivate let previous: Session?
    }

    fileprivate struct Session: Sendable {
        let roots: [String]
        var configuration: ACPSessionConfigurationState
        var toolCallIDs: Set<String>
        var plan: ACPPlan?
    }

    private struct Record: Sendable {
        var session: Session
        var setupToken: UUID?
    }

    private let role: Role
    private var sessions: [String: Record] = [:]

    init(role: Role) {
        self.role = role
    }

    func register(
        sessionID: String,
        cwd: String,
        additionalDirectories: [String]?,
        modes: ACPSessionModeState? = nil,
        configOptions: [ACPSessionConfigOption]? = nil
    ) throws {
        guard !sessionID.isEmpty, sessions[sessionID] == nil else {
            throw ACPJSONRPCError.invalidParams
        }
        sessions[sessionID] = try Record(
            session: makeSession(
                cwd: cwd,
                additionalDirectories: additionalDirectories,
                modes: modes,
                configOptions: configOptions
            ),
            setupToken: nil
        )
    }

    func beginSetup(
        sessionID: String,
        cwd: String,
        additionalDirectories: [String]?
    ) throws -> Setup {
        guard !sessionID.isEmpty else { throw ACPJSONRPCError.invalidParams }
        guard sessions[sessionID]?.setupToken == nil else {
            throw ACPJSONRPCError.invalidRequest
        }

        let token = UUID()
        let previous = sessions[sessionID]?.session
        sessions[sessionID] = try Record(
            session: makeSession(cwd: cwd, additionalDirectories: additionalDirectories),
            setupToken: token
        )
        return Setup(token: token, previous: previous)
    }

    func completeSetup(
        sessionID: String,
        modes: ACPSessionModeState?,
        configOptions: [ACPSessionConfigOption]?,
        setup: Setup
    ) throws {
        guard var record = sessions[sessionID], record.setupToken == setup.token else {
            throw missingSessionError(sessionID)
        }
        record.session.configuration = try ACPSessionConfigurationState(
            modes: modes,
            configOptions: configOptions
        )
        record.setupToken = nil
        sessions[sessionID] = record
    }

    func rollback(sessionID: String, setup: Setup) {
        guard sessions[sessionID]?.setupToken == setup.token else { return }
        sessions[sessionID] = setup.previous.map { Record(session: $0, setupToken: nil) }
    }

    func require(_ sessionID: String) throws {
        guard sessions[sessionID] != nil else { throw missingSessionError(sessionID) }
    }

    func remove(_ sessionID: String) {
        sessions[sessionID] = nil
    }

    func snapshot(
        _ sessionID: String
    ) throws -> (
        roots: [String],
        modes: ACPSessionModeState?,
        configOptions: [ACPSessionConfigOption]?,
        plan: ACPPlan?
    ) {
        guard let session = sessions[sessionID]?.session else {
            throw missingSessionError(sessionID)
        }
        return (
            roots: session.roots,
            modes: session.configuration.modes,
            configOptions: session.configuration.configOptions,
            plan: session.plan
        )
    }

    func effectiveRoots(_ sessionID: String) throws -> [String] {
        guard let roots = sessions[sessionID]?.session.roots else {
            throw missingSessionError(sessionID)
        }
        return roots
    }

    func requirePath(_ path: String, sessionID: String) throws {
        try WorkspacePathPolicy.require(path, within: effectiveRoots(sessionID))
    }

    func validateMode(_ modeID: String, sessionID: String) throws {
        guard let session = sessions[sessionID]?.session else {
            throw missingSessionError(sessionID)
        }
        try session.configuration.validate(modeID: modeID)
    }

    func setCurrentMode(_ modeID: String, sessionID: String) throws {
        guard var record = sessions[sessionID] else { throw missingSessionError(sessionID) }
        try record.session.configuration.applyCurrentMode(modeID)
        sessions[sessionID] = record
    }

    func validateConfig(
        _ configID: String,
        value: ACPSessionConfigValue,
        sessionID: String
    ) throws {
        guard let session = sessions[sessionID]?.session else {
            throw missingSessionError(sessionID)
        }
        try session.configuration.validate(configID: configID, value: value)
    }

    func replaceConfigOptions(
        _ configOptions: [ACPSessionConfigOption],
        sessionID: String
    ) throws {
        guard var record = sessions[sessionID] else { throw missingSessionError(sessionID) }
        try record.session.configuration.replaceConfigOptions(configOptions)
        sessions[sessionID] = record
    }

    func apply(_ notification: ACPSessionNotification) throws {
        guard var record = sessions[notification.sessionID] else {
            throw missingSessionError(notification.sessionID)
        }

        switch notification.update {
        case .toolCall(let toolCall):
            guard !toolCall.toolCallID.isEmpty,
                record.session.toolCallIDs.insert(toolCall.toolCallID).inserted
            else {
                throw ACPJSONRPCError.invalidParams
            }
        case .toolCallUpdate(let update):
            guard record.session.toolCallIDs.contains(update.toolCallID) else {
                throw ACPJSONRPCError.invalidParams
            }
        case .currentModeUpdate(let update):
            switch role {
            case .client:
                try record.session.configuration.applyCurrentMode(update.currentModeID)
            case .agent:
                try record.session.configuration.validate(modeID: update.currentModeID)
            }
        case .configOptionUpdate(let update):
            try record.session.configuration.replaceConfigOptions(update.configOptions)
        case .plan(let plan) where role == .client:
            record.session.plan = plan
        default:
            break
        }
        sessions[notification.sessionID] = record
    }

    func plan(sessionID: String) -> ACPPlan? {
        sessions[sessionID]?.session.plan
    }

    private func makeSession(
        cwd: String,
        additionalDirectories: [String]?,
        modes: ACPSessionModeState? = nil,
        configOptions: [ACPSessionConfigOption]? = nil
    ) throws -> Session {
        try Session(
            roots: [cwd] + (additionalDirectories ?? []),
            configuration: ACPSessionConfigurationState(
                modes: modes,
                configOptions: configOptions
            ),
            toolCallIDs: [],
            plan: nil
        )
    }

    private func missingSessionError(_ sessionID: String) -> any Error {
        switch role {
        case .client:
            return ACPAgentClientError.sessionNotEstablished(sessionID)
        case .agent:
            return ACPJSONRPCError.resourceNotFound
        }
    }
}
