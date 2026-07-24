import ACPModel

enum SessionSetupValidator {
    static func validate(
        cwd: String,
        additionalDirectories: [String]?,
        mcpServers: [ACPMCPServer],
        capabilities: ACPAgentCapabilities
    ) throws {
        try validatePaths(cwd: cwd, additionalDirectories: additionalDirectories)
        guard
            additionalDirectories == nil
                || capabilities.sessionCapabilities.additionalDirectories != nil
        else {
            throw ACPJSONRPCError.invalidParams
        }
        try validate(mcpServers: mcpServers, capabilities: capabilities.mcpCapabilities)
    }

    static func validate(listResponse: ACPListSessionsResponse) throws {
        for session in listResponse.sessions {
            try validatePaths(cwd: session.cwd, additionalDirectories: session.additionalDirectories)
        }
    }

    private static func validatePaths(
        cwd: String,
        additionalDirectories: [String]?
    ) throws {
        try WorkspacePathPolicy.requireAbsolute(cwd)
        for path in additionalDirectories ?? [] {
            try WorkspacePathPolicy.requireAbsolute(path)
        }
    }

    private static func validate(
        mcpServers: [ACPMCPServer],
        capabilities: ACPMCPCapabilities
    ) throws {
        for server in mcpServers {
            switch server {
            case .stdio(let stdio):
                try WorkspacePathPolicy.requireAbsolute(stdio.command)
            case .http where !capabilities.http,
                .sse where !capabilities.sse:
                throw ACPJSONRPCError.invalidParams
            default:
                break
            }
        }
    }
}
