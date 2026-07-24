import ACPModel

import Foundation
import OSLog

extension ACPConnection {
    func requestValue(
        method: String,
        params: ACPValue?,
        waitsForPrecedingNotifications: Bool = false
    ) async throws -> ACPValue {
        guard canSend else {
            throw ACPConnectionError.closed
        }

        let id = outbound.allocateRequestID()

        acpConnectionLogger.debug(
            "Sending request id=\(String(describing: id), privacy: .public) method=\(method, privacy: .public)"
        )

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let sendTask = Task { [self] in
                    do {
                        try await sendMessage(.request(id: id, method: method, params: params))
                        await requestWasSent(id: id)
                    } catch {
                        failRequest(id: id, error: error)
                        throw error
                    }
                }
                outbound.pending[id] = ConnectionPendingRequest(
                    complete: { result in
                        continuation.resume(with: result)
                    },
                    waitsForPrecedingNotifications: waitsForPrecedingNotifications,
                    sendTask: sendTask,
                    timeoutTask: makeTimeoutTask(id: id, method: method)
                )
            }
        } onCancel: {
            Task {
                await self.cancelRequest(id: id)
            }
        }
    }

    func cancelRequest(id: ACPRequestID) async {
        guard var request = outbound.pending[id], !request.cancellationRequested else {
            return
        }
        request.cancellationRequested = true
        outbound.pending[id] = request
        if request.sent { await sendCancellation(id: id) }
    }

    func requestWasSent(id: ACPRequestID) async {
        guard var request = outbound.pending[id] else { return }
        request.sent = true
        outbound.pending[id] = request
        if request.cancellationRequested { await sendCancellation(id: id) }
    }

    func sendCancellation(id: ACPRequestID) async {
        let cancellation = ACPCancelRequestNotification(requestID: id)
        try? await sendMessage(
            .notification(
                method: ACPProtocol.Method.cancelRequest,
                params: try ACPValue.encode(cancellation)
            )
        )
    }

    func requestTimedOut(id: ACPRequestID, method: String) async {
        guard let request = removePendingRequest(id: id) else { return }
        request.complete(.failure(ACPConnectionError.requestTimedOut(method: method)))
        if request.sent {
            if !request.cancellationRequested {
                await sendCancellation(id: id)
            }
            return
        }
        Task { [self, sendTask = request.sendTask] in
            guard case .success = await sendTask.result else { return }
            await sendCancellation(id: id)
        }
    }

    func makeTimeoutTask(id: ACPRequestID, method: String) -> Task<Void, Never>? {
        guard let requestTimeout else { return nil }
        return Task { [self] in
            do {
                try await Task.sleep(for: requestTimeout)
            } catch {
                return
            }
            await requestTimedOut(id: id, method: method)
        }
    }

    func failRequest(id: ACPRequestID, error: Error) {
        acpConnectionLogger.error(
            "Failed pending request id=\(String(describing: id), privacy: .public) error=\(error.localizedDescription, privacy: .public)"
        )
        removePendingRequest(id: id)?.complete(.failure(error))
    }

    func completeReceivedRequest(id: ACPRequestID, with result: Result<ACPValue, Error>) {
        guard let request = removePendingRequest(id: id) else {
            return
        }

        guard request.waitsForPrecedingNotifications,
            let notificationTail = inbound.notificationTail
        else {
            request.complete(result)
            return
        }

        Task {
            await notificationTail.value
            request.complete(result)
        }
    }

    func removePendingRequest(id: ACPRequestID) -> ConnectionPendingRequest? {
        let request = outbound.pending.removeValue(forKey: id)
        request?.timeoutTask?.cancel()
        return request
    }

    var canSend: Bool {
        if case .running = lifecycle.phase { return true }
        return false
    }

    func sendMessage(_ message: ACPJSONRPCMessage) async throws {
        let (sendCompletion, finishSend) = AsyncStream<Void>.makeStream()
        let precedingSends = lifecycle.sendTail
        lifecycle.sendTail = Task {
            await precedingSends?.value
            for await _ in sendCompletion {}
        }
        defer { finishSend.finish() }

        wireEvents.willSend(message)
        do {
            try await transport.send(message)
            wireEvents.didSend(message)
        } catch {
            wireEvents.sendFailed(message)
            throw error
        }
    }
}
