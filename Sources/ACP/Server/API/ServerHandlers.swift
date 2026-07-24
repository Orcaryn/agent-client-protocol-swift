import ACPModel

public struct ACPAgentServerHandlers: Sendable {
    public let lifecycle: ACPAgentLifecycleHandlers
    public let sessions: ACPAgentSessionHandlers
    public let extensions: ACPAgentExtensionHandlers

    public init(
        lifecycle: ACPAgentLifecycleHandlers,
        sessions: ACPAgentSessionHandlers,
        extensions: ACPAgentExtensionHandlers = ACPAgentExtensionHandlers()
    ) {
        self.lifecycle = lifecycle
        self.sessions = sessions
        self.extensions = extensions
    }
}

public struct ACPAgentLifecycleHandlers: Sendable {
    public typealias InitializeHandler =
        @Sendable (ACPAgentContext, ACPInitializeRequest) async throws -> ACPInitializeResponse
    public typealias AuthenticateHandler =
        @Sendable (ACPAgentContext, ACPAuthenticateRequest) async throws -> ACPAuthenticateResponse
    public typealias LogoutHandler =
        @Sendable (ACPAgentContext, ACPLogoutRequest) async throws -> ACPLogoutResponse

    public let initialize: InitializeHandler
    public let authenticate: AuthenticateHandler?
    public let logout: LogoutHandler?

    public init(
        initialize: @escaping InitializeHandler,
        authenticate: AuthenticateHandler? = nil,
        logout: LogoutHandler? = nil
    ) {
        self.initialize = initialize
        self.authenticate = authenticate
        self.logout = logout
    }
}

public struct ACPAgentSessionHandlers: Sendable {
    public typealias NewHandler =
        @Sendable (ACPAgentContext, ACPNewSessionRequest) async throws -> ACPNewSessionResponse
    public typealias LoadHandler =
        @Sendable (ACPAgentContext, ACPLoadSessionRequest) async throws -> ACPLoadSessionResponse
    public typealias ResumeHandler =
        @Sendable (ACPAgentContext, ACPResumeSessionRequest) async throws -> ACPResumeSessionResponse
    public typealias ListHandler =
        @Sendable (ACPAgentContext, ACPListSessionsRequest) async throws -> ACPListSessionsResponse
    public typealias CommandHandler =
        @Sendable (ACPAgentContext, ACPSessionIDRequest) async throws -> ACPEmptyResponse
    public typealias PromptHandler =
        @Sendable (ACPAgentContext, ACPPromptRequest) async throws -> ACPPromptResponse
    public typealias SetModeHandler =
        @Sendable (ACPAgentContext, ACPSetSessionModeRequest) async throws -> ACPEmptyResponse
    public typealias SetConfigOptionHandler =
        @Sendable (ACPAgentContext, ACPSetConfigOptionRequest) async throws -> ACPSetConfigOptionResponse
    public typealias CancelHandler =
        @Sendable (ACPAgentContext, ACPCancelSessionNotification) async -> Void

    public let new: NewHandler
    public let prompt: PromptHandler
    public let load: LoadHandler?
    public let resume: ResumeHandler?
    public let list: ListHandler?
    public let delete: CommandHandler?
    public let close: CommandHandler?
    public let setMode: SetModeHandler?
    public let setConfigOption: SetConfigOptionHandler?
    public let cancel: CancelHandler?

    public init(
        new: @escaping NewHandler,
        prompt: @escaping PromptHandler,
        load: LoadHandler? = nil,
        resume: ResumeHandler? = nil,
        list: ListHandler? = nil,
        delete: CommandHandler? = nil,
        close: CommandHandler? = nil,
        setMode: SetModeHandler? = nil,
        setConfigOption: SetConfigOptionHandler? = nil,
        cancel: CancelHandler? = nil
    ) {
        self.new = new
        self.prompt = prompt
        self.load = load
        self.resume = resume
        self.list = list
        self.delete = delete
        self.close = close
        self.setMode = setMode
        self.setConfigOption = setConfigOption
        self.cancel = cancel
    }
}

public struct ACPAgentExtensionHandlers: Sendable {
    public typealias RequestHandler =
        @Sendable (ACPAgentContext, String, ACPValue?) async throws -> ACPValue
    public typealias NotificationHandler =
        @Sendable (ACPAgentContext, String, ACPValue?) async -> Void

    public let request: RequestHandler?
    public let notification: NotificationHandler?

    public init(request: RequestHandler? = nil, notification: NotificationHandler? = nil) {
        self.request = request
        self.notification = notification
    }
}
