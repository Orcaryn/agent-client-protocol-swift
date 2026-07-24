import ACPModel

import Foundation

actor ACPPermissionCoordinator {
    private typealias PermissionResult = Result<ACPRequestPermissionResponse, Error>

    private static let cancelledResponse = ACPRequestPermissionResponse(outcome: .cancelled)

    private struct PendingRequest: Sendable {
        let handler: Task<Void, Never>
        let resume: @Sendable (PermissionResult) -> Void
    }

    private var pendingRequests: [String: [UUID: PendingRequest]] = [:]
    private var cancelledSessions: Set<String> = []

    func request(
        _ request: ACPRequestPermissionRequest,
        handler: @escaping ACPClientSessionCallbacks.PermissionHandler
    ) async throws -> ACPRequestPermissionResponse {
        if cancelledSessions.contains(request.sessionID) {
            return Self.cancelledResponse
        }

        let id = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let handlerTask = Task { [weak self] in
                    let result: PermissionResult
                    do {
                        result = .success(try await handler(request))
                    } catch is CancellationError {
                        result = .success(Self.cancelledResponse)
                    } catch {
                        result = .failure(error)
                    }
                    await self?.settle(
                        id: id,
                        sessionID: request.sessionID,
                        result: result
                    )
                }
                pendingRequests[request.sessionID, default: [:]][id] = PendingRequest(
                    handler: handlerTask,
                    resume: { result in continuation.resume(with: result) }
                )

                if Task.isCancelled {
                    settle(
                        id: id,
                        sessionID: request.sessionID,
                        result: .failure(CancellationError()),
                        cancellingHandler: true
                    )
                }
            }
        } onCancel: {
            Task {
                await self.settle(
                    id: id,
                    sessionID: request.sessionID,
                    result: .failure(CancellationError()),
                    cancellingHandler: true
                )
            }
        }
    }

    func beginPrompt(sessionID: String) {
        cancelledSessions.remove(sessionID)
    }

    func cancel(sessionID: String) {
        cancelledSessions.insert(sessionID)
        guard let requests = pendingRequests.removeValue(forKey: sessionID) else { return }
        for request in requests.values {
            request.handler.cancel()
            request.resume(.success(Self.cancelledResponse))
        }
    }

    private func settle(
        id: UUID,
        sessionID: String,
        result: PermissionResult,
        cancellingHandler: Bool = false
    ) {
        guard
            let request = pendingRequests[sessionID]?.removeValue(forKey: id)
        else {
            return
        }
        if pendingRequests[sessionID]?.isEmpty == true {
            pendingRequests[sessionID] = nil
        }
        if cancellingHandler {
            request.handler.cancel()
        }
        request.resume(result)
    }
}
