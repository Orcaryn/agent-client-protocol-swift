import ACPModel

import Foundation
import OSLog

extension ACPConnection {
    func receive(_ message: ACPJSONRPCMessage) async {
        wireEvents.receive(message)

        switch message {
        case .response(let id, let result):
            acpConnectionLogger.debug("Received response id=\(String(describing: id), privacy: .public)")
            completeReceivedRequest(id: id, with: .success(result))

        case .error(let id, let error):
            acpConnectionLogger.error(
                "Received error id=\(String(describing: id), privacy: .public) code=\(error.code.rawValue) message=\(error.message, privacy: .public)"
            )
            completeReceivedRequest(id: id, with: .failure(error))

        case .notification(let method, let params):
            acpConnectionLogger.debug("Received notification method=\(method, privacy: .public)")

            if method == ACPProtocol.Method.cancelRequest,
                let params,
                let cancellation = try? params.decode(ACPCancelRequestNotification.self)
            {
                inbound.activeRequests.removeValue(forKey: cancellation.requestID)?.cancel()
                return
            }

            enqueueNotification(method: method, params: params)

        case .request(let id, let method, let params):
            acpConnectionLogger.debug(
                "Received request id=\(String(describing: id), privacy: .public) method=\(method, privacy: .public)"
            )
            await requestRouting.received?(id, method, params)
            let task = Task { [self] in
                await handleRequest(id: id, method: method, params: params)
            }
            inbound.activeRequests[id] = task
        }
    }

    func handleRequest(id: ACPRequestID, method: String, params: ACPValue?) async {
        do {
            let result = try await requestRouting.handle(self, id, method, params)
            try await sendMessage(.response(id: id, result: result))
            acpConnectionLogger.debug(
                "Sent response id=\(String(describing: id), privacy: .public) method=\(method, privacy: .public)"
            )
        } catch is CancellationError {
            try? await sendMessage(.error(id: id, error: .requestCancelled))
        } catch let error as ACPJSONRPCError {
            acpConnectionLogger.error(
                "Request failed id=\(String(describing: id), privacy: .public) method=\(method, privacy: .public) code=\(error.code.rawValue) message=\(error.message, privacy: .public)"
            )
            try? await sendMessage(.error(id: id, error: error))
        } catch is DecodingError {
            acpConnectionLogger.error(
                "Invalid request params id=\(String(describing: id), privacy: .public) method=\(method, privacy: .public)"
            )
            try? await sendMessage(.error(id: id, error: .invalidParams))
        } catch {
            acpConnectionLogger.error(
                "Request failed id=\(String(describing: id), privacy: .public) method=\(method, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
            )
            try? await sendMessage(.error(id: id, error: .internalError))
        }

        await requestRouting.finished?(id)
        inbound.activeRequests[id] = nil
    }

    func enqueueNotification(method: String, params: ACPValue?) {
        guard let handler = handlers.onNotification else { return }

        let sequence = inbound.nextNotificationSequence
        inbound.nextNotificationSequence += 1
        let previous = inbound.notificationTail
        let task = Task { [self] in
            await previous?.value
            if !Task.isCancelled {
                await runNotification(sequence: sequence) {
                    await handler(self, method, params)
                }
            }
        }
        inbound.notificationTail = task
    }

    func runNotification(
        sequence: UInt64,
        operation: @Sendable () async -> Void
    ) async {
        inbound.activeNotificationSequence = sequence
        await ACPNotificationContext.$sequence.withValue(sequence) {
            await operation()
        }
        if inbound.activeNotificationSequence == sequence {
            inbound.activeNotificationSequence = nil
        }
    }

    var isInsideNotificationCallback: Bool {
        guard let sequence = ACPNotificationContext.sequence else { return false }
        return sequence == inbound.activeNotificationSequence
    }
}
