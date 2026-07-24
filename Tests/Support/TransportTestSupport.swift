import Foundation

import ACP
import ACPModel

package actor TransportEvents {
    package private(set) var messages: [ACPJSONRPCMessage] = []
    package private(set) var logs: [String] = []
    package private(set) var terminations: [ACPTransportTermination] = []

    package init() {}

    package func record(_ message: ACPJSONRPCMessage) {
        messages.append(message)
    }

    package func record(_ termination: ACPTransportTermination) {
        terminations.append(termination)
    }

    package func record(log: String) {
        logs.append(log)
    }
}

package actor RawMessageEvents {
    package private(set) var messages: [(direction: ACPRawMessageDirection, data: Data)] = []

    package init() {}

    package func record(direction: ACPRawMessageDirection, data: Data) {
        messages.append((direction, data))
    }
}

package actor AsyncGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    package init() {}

    package func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    package func open() {
        isOpen = true
        let current = waiters
        waiters.removeAll()
        for waiter in current { waiter.resume() }
    }
}

package func eventually(
    for timeout: Duration = .seconds(2),
    _ predicate: @escaping @Sendable () async -> Bool
) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)

    while clock.now < deadline {
        if await predicate() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }

    return await predicate()
}
