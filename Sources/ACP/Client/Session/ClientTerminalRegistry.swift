import ACPModel

actor ClientTerminalRegistry {
    private struct Terminal: Sendable {
        let outputByteLimit: UInt64?
    }

    private var sessions: [String: [String: Terminal]] = [:]

    func register(_ request: ACPCreateTerminalRequest, terminalID: String) throws {
        guard sessions[request.sessionID]?[terminalID] == nil else {
            throw ACPJSONRPCError.invalidParams
        }
        sessions[request.sessionID, default: [:]][terminalID] = Terminal(
            outputByteLimit: request.outputByteLimit
        )
    }

    func require(_ request: ACPTerminalRequest) throws {
        guard sessions[request.sessionID]?[request.terminalID] != nil else {
            throw ACPJSONRPCError.resourceNotFound
        }
    }

    func release(_ request: ACPTerminalRequest) {
        sessions[request.sessionID]?[request.terminalID] = nil
    }

    func clear(sessionID: String) {
        sessions[sessionID] = nil
    }

    func limit(
        _ response: ACPTerminalOutputResponse,
        for request: ACPTerminalRequest
    ) -> ACPTerminalOutputResponse {
        guard let limit = sessions[request.sessionID]?[request.terminalID]?.outputByteLimit,
            response.output.utf8.count > limit,
            let byteLimit = Int(exactly: limit)
        else {
            return response
        }

        var start = response.output.endIndex
        var retainedBytes = 0
        while start > response.output.startIndex {
            let candidate = response.output.index(before: start)
            let characterBytes = response.output[candidate..<start].utf8.count
            if retainedBytes + characterBytes > byteLimit { break }
            retainedBytes += characterBytes
            start = candidate
        }

        return ACPTerminalOutputResponse(
            output: String(response.output[start...]),
            truncated: true,
            exitStatus: response.exitStatus,
            _meta: response._meta
        )
    }
}
