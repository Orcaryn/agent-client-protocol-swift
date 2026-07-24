import ACPModel

actor PromptCoordinator {
    private struct Prompt: Sendable {
        let requestID: ACPRequestID
        var task: Task<ACPPromptResponse, Error>?
        var cancelled = false
        var waiters: [CheckedContinuation<Void, Never>] = []
    }

    private var promptsBySession: [String: Prompt] = [:]
    private var sessionByRequest: [ACPRequestID: String] = [:]

    func receive(requestID: ACPRequestID, sessionID: String) {
        sessionByRequest[requestID] = sessionID
        if promptsBySession[sessionID] == nil {
            promptsBySession[sessionID] = Prompt(requestID: requestID)
        }
    }

    func abandon(requestID: ACPRequestID) {
        guard let sessionID = sessionByRequest.removeValue(forKey: requestID) else { return }
        guard let prompt = promptsBySession[sessionID],
            prompt.requestID == requestID,
            prompt.task == nil
        else {
            return
        }
        promptsBySession[sessionID] = nil
        resume(prompt.waiters)
    }

    func start(
        requestID: ACPRequestID,
        sessionID: String,
        operation: @escaping @Sendable () async throws -> ACPPromptResponse
    ) throws -> Task<ACPPromptResponse, Error> {
        guard sessionByRequest[requestID] == sessionID,
            var prompt = promptsBySession[sessionID],
            prompt.requestID == requestID,
            prompt.task == nil
        else {
            throw ACPJSONRPCError.invalidRequest
        }

        let task = Task { try await operation() }
        prompt.cancelled = prompt.cancelled || Task.isCancelled
        prompt.task = task
        promptsBySession[sessionID] = prompt
        if prompt.cancelled { task.cancel() }
        return task
    }

    func cancel(sessionID: String) {
        guard var prompt = promptsBySession[sessionID] else { return }
        prompt.cancelled = true
        prompt.task?.cancel()
        promptsBySession[sessionID] = prompt
    }

    func waitUntilFinished(sessionID: String) async {
        guard promptsBySession[sessionID] != nil else { return }
        await withCheckedContinuation { continuation in
            promptsBySession[sessionID]?.waiters.append(continuation)
        }
    }

    func finish(sessionID: String) -> Bool {
        guard let prompt = promptsBySession[sessionID], prompt.task != nil else { return false }
        promptsBySession[sessionID] = nil
        resume(prompt.waiters)
        return prompt.cancelled
    }

    private func resume(_ waiters: [CheckedContinuation<Void, Never>]) {
        for waiter in waiters { waiter.resume() }
    }
}
