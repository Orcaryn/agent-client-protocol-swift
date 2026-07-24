import ACPModel

import Foundation
import OSLog

extension ACPConnection {
    func transportTerminated(_ termination: ACPTransportTermination) {
        switch lifecycle.phase {
        case .draining, .closed:
            return
        case .idle, .running, .closing:
            lifecycle.phase = .draining
        }

        acpConnectionLogger.error(
            "Connection terminated reason=\(String(describing: termination), privacy: .public)"
        )
        let pending = Array(outbound.pending.values)
        outbound.pending.removeAll()
        let active = Array(inbound.activeRequests.values)
        inbound.activeRequests.removeAll()
        let notificationDrain = inbound.notificationTail
        inbound.notificationTail = nil

        for request in active {
            request.cancel()
        }

        for request in pending {
            request.timeoutTask?.cancel()
            request.complete(.failure(termination))
        }

        // Avoid awaiting the current request when a transport terminates from inside send().
        Task { [self] in
            await drainAndFinishTermination(
                termination,
                requests: active,
                notificationDrain: notificationDrain
            )
        }
    }

    func drainAndFinishTermination(
        _ termination: ACPTransportTermination,
        requests: [Task<Void, Never>],
        notificationDrain: Task<Void, Never>?
    ) async {
        for request in requests {
            await request.value
        }
        await notificationDrain?.value
        let sendDrain = lifecycle.sendTail
        lifecycle.sendTail = nil
        await sendDrain?.value
        let wireDrain = wireEvents.finish()
        await wireDrain?.value

        if let externalHandler = handlers.onTermination {
            await externalHandler(termination)
        }

        lifecycle.phase = .closed
        lifecycle.termination = termination
        resumeCloseWaiters(returning: termination)
    }

    func finishWithoutTransport() {
        lifecycle.phase = .closed
        lifecycle.termination = .terminated

        resumeCloseWaiters(returning: .terminated)
    }

    func resumeCloseWaiters(returning termination: ACPTransportTermination) {
        let waiters = lifecycle.closeWaiters
        lifecycle.closeWaiters.removeAll()
        for waiter in waiters {
            waiter.resume(returning: termination)
        }
    }
}
