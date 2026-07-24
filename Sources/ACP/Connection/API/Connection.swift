import ACPModel

import Foundation
import OSLog

let acpConnectionLogger = Logger(
    subsystem: "org.agentclientprotocol.swift-acp",
    category: "ACPConnection"
)

public actor ACPConnection {
    let transport: any ACPMessageTransport
    let handlers: ACPConnectionHandlers
    let requestRouting: ACPInboundRequestRouting
    let requestTimeout: Duration?
    var outbound = ConnectionOutboundState()
    var inbound = ConnectionInboundState()
    var wireEvents: WireEventRecorder
    var lifecycle = ConnectionLifecycleState()

    public init(
        transport: any ACPMessageTransport,
        handlers: ACPConnectionHandlers = ACPConnectionHandlers(),
        requestTimeout: Duration? = nil
    ) {
        self.transport = transport
        self.handlers = handlers
        self.requestTimeout = validatedRequestTimeout(requestTimeout)
        wireEvents = WireEventRecorder(inspection: handlers.wireInspection)
        requestRouting = ACPInboundRequestRouting(handle: { connection, _, method, params in
            guard let handler = handlers.onRequest else {
                throw ACPJSONRPCError.methodNotFound
            }
            return try await handler(connection, method, params)
        })
    }

    init(
        transport: any ACPMessageTransport,
        handlers: ACPConnectionHandlers,
        requestRouting: ACPInboundRequestRouting,
        requestTimeout: Duration? = nil
    ) {
        self.transport = transport
        self.handlers = handlers
        self.requestTimeout = validatedRequestTimeout(requestTimeout)
        wireEvents = WireEventRecorder(inspection: handlers.wireInspection)
        self.requestRouting = requestRouting
    }

    public func start() async throws {
        switch lifecycle.phase {
        case .idle:
            lifecycle.phase = .running
        case .running:
            throw ACPTransportError.alreadyStarted
        case .closing, .draining, .closed:
            throw ACPConnectionError.closed
        }
        acpConnectionLogger.debug("Starting connection")
        do {
            try await transport.start(
                onMessage: { [weak self] message in
                    await self?.receive(message)
                },
                onLog: { [handlers] message in
                    await handlers.onLog?(message)
                },
                onTermination: { [weak self] termination in
                    await self?.transportTerminated(termination)
                }
            )
        } catch {
            if case .running = lifecycle.phase {
                lifecycle.phase = .idle
            }
            throw error
        }
    }
}
