# Agent Client Protocol (Swift)

Build ACP-compliant clients and agents in Swift with type-safe protocol models, async
runtimes, and newline-delimited JSON transports.

The [Agent Client Protocol (ACP)](https://agentclientprotocol.com) standardizes
communication between code editors and AI coding agents.

Built for [Chapeta](https://chapeta.net), an instant AI panel for any provider or agent,
right over your work.

## At a glance

- Type-safe `Codable` and `Sendable` models for stable ACP v1
- Actor-based client and agent runtimes built for Swift concurrency
- Capability-aware sessions, permissions, filesystem access, and terminals
- Authentication, MCP server configuration, session modes, and config options
- One-way client event streams and opt-in, redacted JSON-RPC wire inspection
- Custom transports and underscore-prefixed protocol extensions

## Requirements

- Swift 6.2+
- macOS 13+

## Installation

Add the package dependency:

```swift
dependencies: [
    .package(
        url: "https://github.com/Orcaryn/agent-client-protocol-swift.git",
        from: "1.0.0"
    )
]
```

Then add the products needed by your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "ACPModel", package: "agent-client-protocol-swift"),
        .product(name: "ACP", package: "agent-client-protocol-swift"),
        // Optional: launch local ACP agents as subprocesses.
        .product(name: "ACPProcess", package: "agent-client-protocol-swift"),
    ]
)
```

The package is split by responsibility:

- `ACPModel` contains only the protocol and JSON-RPC value types.
- `ACP` contains the client and agent runtimes.
- `ACPProcess` launches and manages local agents over stdio.

On Darwin, starting an `ACPProcess` ignores `SIGPIPE` process-wide. This makes a
closed agent stdin fail the send operation instead of terminating the host
process.

## Getting started

### Client

Launch an ACP agent, initialize the connection, create a session, and send a prompt:

```swift
import ACP
import ACPModel
import ACPProcess
import Foundation

let client = ACPAgentClient(
    launch: ACPProcessLaunch(executableURL: URL(fileURLWithPath: "/path/to/agent")),
    clientInfo: ACPImplementationInfo(name: "my-client", version: "1.0.0")
)

let events = await client.events()
let eventTask = Task {
    for await event in events {
        if case .sessionUpdate(let notification) = event {
            print(notification.update)
        }
    }
}

try await client.connect()
let session = try await client.newSession(cwd: FileManager.default.currentDirectoryPath)
let response = try await client.prompt(
    sessionID: session.sessionID,
    content: [.text(ACPTextContent(text: "Review this project"))]
)
await client.shutdown()
await eventTask.value
```

Enable matching `ACPClientCapabilities` for filesystem or terminal callbacks. The runtime
restricts callback paths to the session working directory and its additional directories.
Callbacks remain the right API for requests that need an answer, such as permissions and
filesystem access; `events()` is the one-way stream for session updates, logs, termination,
and optional wire events.

Use `sessionSnapshot(sessionID:)` for the client runtime's read-only view of session roots,
modes, configuration options, and the latest plan. Long-lived integrations can await
`waitUntilClosed()`. An optional connection-wide `requestTimeout` is available on client,
server, and connection initializers; it defaults to `nil`, so prompt turns remain unbounded
unless an application explicitly opts in.

### Agent

Implement the required lifecycle handlers and stream updates through the request context:

```swift
import ACP
import ACPModel
import Foundation

let server = ACPAgentServer(
    handlers: ACPAgentServerHandlers(
        lifecycle: ACPAgentLifecycleHandlers(
            initialize: { _, request in
                ACPInitializeResponse(protocolVersion: request.protocolVersion)
            }
        ),
        sessions: ACPAgentSessionHandlers(
            new: { _, _ in
                ACPNewSessionResponse(sessionID: UUID().uuidString)
            },
            prompt: { context, request in
                try await context.sessionUpdate(
                    ACPSessionNotification(
                        sessionID: request.sessionID,
                        update: .agentMessageChunk(
                            ACPContentChunk(content: .text(ACPTextContent(text: "Done")))
                        )
                    )
                )
                return ACPPromptResponse(stopReason: .endTurn)
            }
        )
    )
)

try await server.run()
```

`ACPAgentServer` uses `ACPStandardIOTransport` by default. Optional handlers add
authentication, session persistence, modes, config options, cancellation, and extensions.
The request context exposes capability-gated filesystem, terminal, permission, and custom
method calls back to the client. Requests for advertised features without matching handlers
receive the standard JSON-RPC `methodNotFound` error.

### Inspect the wire

Wire inspection is off by default. Opt in while diagnosing an integration:

```swift
let client = ACPAgentClient(
    transport: transport,
    wireInspection: ACPWireInspection { event in
        print(event.direction, event.method ?? "response", event.rawJSON ?? "<omitted>")
    }
)
```

The `ACPAgentClient(launch:)` convenience initializer accepts the same `wireInspection`
option. `ACPAgentServer` also supports wire inspection for both directions.

Sensitive keys are recursively redacted and oversized JSON payloads are omitted. Wire events
are also available through `client.events()`.

### Runnable examples

The [`Examples`](Examples) directory contains a small but real ACP pair: Field Notes streams
plan, thought, message, and illustrative usage updates; Trail launches a local ACP executable
and prints its event stream. If an agent requires command-line arguments, place them before
`--`; everything after `--` becomes the prompt.

```sh
swift build
swift run acp-trail .build/debug/acp-hello-agent "Hello"
swift run acp-trail .build/debug/acp-field-notes-agent "Orient me to this workspace"
# Agent arguments followed by a prompt:
swift run acp-trail /path/to/agent --mode acp -- "Hello"
```

`ACPHelloAgent` is the smallest example: initialization, session creation, and one prompt
response. Field Notes demonstrates streamed plans, thoughts, messages, and an explicitly
synthetic usage update.

## Protocol coverage

This package implements stable ACP protocol version 1 from schema
[v1.19.0](https://github.com/agentclientprotocol/agent-client-protocol/releases/tag/schema-v1.19.0)
(published with the upstream
[v1.4.0 release](https://github.com/agentclientprotocol/agent-client-protocol/releases/tag/v1.4.0)),
including:

- Initialization, authentication, and logout
- Session creation, loading, resumption, listing, deletion, and closing
- Prompts, cancellation, modes, and typed config options
- All 11 stable session update variants, including tool calls, plans, usage, and session info
- Permission requests plus client-provided filesystem and terminal operations
- Stdio, HTTP, and SSE MCP server configuration models
- JSON-RPC request cancellation through `$/cancel_request`
- `_meta` values and underscore-prefixed extension requests and notifications
- Newline-delimited stdio with a configurable 64 MiB default frame limit

Draft ACP features are not included.

## Development

```sh
swift test -Xswiftc -warnings-as-errors
```

The test suite pins the upstream v1.19.0 JSON schema and checks that the package's stable
method and session-update inventories stay aligned with it.

## License

Apache License 2.0.
