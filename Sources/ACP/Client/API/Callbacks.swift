import ACPModel

public struct ACPAgentClientCallbacks: Sendable {
    public let session: ACPClientSessionCallbacks
    public let fileSystem: ACPClientFileSystemCallbacks
    public let terminal: ACPClientTerminalCallbacks
    public let extensions: ACPClientExtensionCallbacks
    public let lifecycle: ACPClientLifecycleCallbacks

    public init(
        session: ACPClientSessionCallbacks = ACPClientSessionCallbacks(),
        fileSystem: ACPClientFileSystemCallbacks = ACPClientFileSystemCallbacks(),
        terminal: ACPClientTerminalCallbacks = ACPClientTerminalCallbacks(),
        extensions: ACPClientExtensionCallbacks = ACPClientExtensionCallbacks(),
        lifecycle: ACPClientLifecycleCallbacks = ACPClientLifecycleCallbacks()
    ) {
        self.session = session
        self.fileSystem = fileSystem
        self.terminal = terminal
        self.extensions = extensions
        self.lifecycle = lifecycle
    }
}

public struct ACPClientSessionCallbacks: Sendable {
    public typealias UpdateHandler = @Sendable (ACPSessionNotification) async -> Void
    public typealias PermissionHandler =
        @Sendable (ACPRequestPermissionRequest) async throws -> ACPRequestPermissionResponse

    public let update: UpdateHandler?
    public let permissionRequest: PermissionHandler?

    public init(update: UpdateHandler? = nil, permissionRequest: PermissionHandler? = nil) {
        self.update = update
        self.permissionRequest = permissionRequest
    }
}

public struct ACPClientFileSystemCallbacks: Sendable {
    public typealias ReadHandler =
        @Sendable (ACPReadTextFileRequest) async throws -> ACPReadTextFileResponse
    public typealias WriteHandler =
        @Sendable (ACPWriteTextFileRequest) async throws -> ACPEmptyResponse

    public let readTextFile: ReadHandler?
    public let writeTextFile: WriteHandler?

    public init(readTextFile: ReadHandler? = nil, writeTextFile: WriteHandler? = nil) {
        self.readTextFile = readTextFile
        self.writeTextFile = writeTextFile
    }
}

public struct ACPClientTerminalCallbacks: Sendable {
    public typealias CreateHandler =
        @Sendable (ACPCreateTerminalRequest) async throws -> ACPCreateTerminalResponse
    public typealias OutputHandler =
        @Sendable (ACPTerminalRequest) async throws -> ACPTerminalOutputResponse
    public typealias WaitForExitHandler =
        @Sendable (ACPTerminalRequest) async throws -> ACPWaitForTerminalExitResponse
    public typealias CommandHandler = @Sendable (ACPTerminalRequest) async throws -> ACPEmptyResponse

    public let create: CreateHandler?
    public let output: OutputHandler?
    public let waitForExit: WaitForExitHandler?
    public let kill: CommandHandler?
    public let release: CommandHandler?

    public init(
        create: CreateHandler? = nil,
        output: OutputHandler? = nil,
        waitForExit: WaitForExitHandler? = nil,
        kill: CommandHandler? = nil,
        release: CommandHandler? = nil
    ) {
        self.create = create
        self.output = output
        self.waitForExit = waitForExit
        self.kill = kill
        self.release = release
    }
}

public struct ACPClientExtensionCallbacks: Sendable {
    public typealias RequestHandler = @Sendable (String, ACPValue?) async throws -> ACPValue
    public typealias NotificationHandler = @Sendable (String, ACPValue?) async -> Void

    public let request: RequestHandler?
    public let notification: NotificationHandler?

    public init(request: RequestHandler? = nil, notification: NotificationHandler? = nil) {
        self.request = request
        self.notification = notification
    }
}

public struct ACPClientLifecycleCallbacks: Sendable {
    public typealias LogHandler = @Sendable (String) async -> Void
    public typealias TerminationHandler = @Sendable (ACPTransportTermination) async -> Void

    public let log: LogHandler?
    public let termination: TerminationHandler?

    public init(log: LogHandler? = nil, termination: TerminationHandler? = nil) {
        self.log = log
        self.termination = termination
    }
}
