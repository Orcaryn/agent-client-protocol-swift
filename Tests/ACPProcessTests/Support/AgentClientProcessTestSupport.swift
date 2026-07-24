import Darwin
import Foundation
import Testing

@testable import ACP
import ACPModel
import ACPProcess

actor SessionUpdates {
    private(set) var values: [ACPSessionNotification] = []

    func append(_ value: ACPSessionNotification) {
        values.append(value)
    }
}

actor ClientMethodCalls {
    private(set) var methods: [String] = []

    func record(_ method: String) {
        methods.append(method)
    }
}

actor ProcessWireEvents {
    private(set) var values: [ACPWireEvent] = []

    func record(_ event: ACPWireEvent) {
        values.append(event)
    }
}

final class ClientLifetimeToken: Sendable {
    func touch() {}
}

actor ClientLifetimeProbe {
    private weak var client: ACPAgentClient?
    private weak var callbackToken: ClientLifetimeToken?

    func track(client: ACPAgentClient, callbackToken: ClientLifetimeToken) {
        self.client = client
        self.callbackToken = callbackToken
    }

    var released: Bool {
        client == nil && callbackToken == nil
    }
}
