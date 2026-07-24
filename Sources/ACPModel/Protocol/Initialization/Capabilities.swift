import Foundation

public struct ACPImplementationInfo: Codable, Equatable, Sendable {
    public let name: String
    @ACPDefaultOnError public var title: String?
    public let version: String
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(name: String, title: String? = nil, version: String, _meta: ACPMeta? = nil) {
        self.name = name
        self.title = title
        self.version = version
        self._meta = _meta
    }
}

public struct ACPFileSystemCapabilities: ACPWireDefault {
    public static var acpDefault: Self { Self() }

    @ACPDefault public var readTextFile: Bool
    @ACPDefault public var writeTextFile: Bool
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(
        readTextFile: Bool = false,
        writeTextFile: Bool = false,
        _meta: ACPMeta? = nil
    ) {
        self.readTextFile = readTextFile
        self.writeTextFile = writeTextFile
        self._meta = _meta
    }
}

public struct ACPBooleanConfigOptionCapabilities: Codable, Equatable, Sendable {
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(_meta: ACPMeta? = nil) {
        self._meta = _meta
    }
}

public struct ACPSessionConfigOptionsCapabilities: Codable, Equatable, Sendable {
    @ACPDefaultOnError public var boolean: ACPBooleanConfigOptionCapabilities?
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(boolean: ACPBooleanConfigOptionCapabilities? = nil, _meta: ACPMeta? = nil) {
        self.boolean = boolean
        self._meta = _meta
    }
}

public struct ACPClientSessionCapabilities: Codable, Equatable, Sendable {
    @ACPDefaultOnError public var configOptions: ACPSessionConfigOptionsCapabilities?
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(configOptions: ACPSessionConfigOptionsCapabilities? = nil, _meta: ACPMeta? = nil) {
        self.configOptions = configOptions
        self._meta = _meta
    }
}

public struct ACPClientCapabilities: ACPWireDefault {
    public static var acpDefault: Self { Self() }

    @ACPDefault public var fs: ACPFileSystemCapabilities
    @ACPDefault public var terminal: Bool
    @ACPDefaultOnError public var session: ACPClientSessionCapabilities?
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(
        fs: ACPFileSystemCapabilities = .acpDefault,
        terminal: Bool = false,
        session: ACPClientSessionCapabilities? = nil,
        _meta: ACPMeta? = nil
    ) {
        self.fs = fs
        self.terminal = terminal
        self.session = session
        self._meta = _meta
    }
}

public struct ACPPromptCapabilities: ACPWireDefault {
    public static var acpDefault: Self { Self() }

    @ACPDefault public var image: Bool
    @ACPDefault public var audio: Bool
    @ACPDefault public var embeddedContext: Bool
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(
        image: Bool = false,
        audio: Bool = false,
        embeddedContext: Bool = false,
        _meta: ACPMeta? = nil
    ) {
        self.image = image
        self.audio = audio
        self.embeddedContext = embeddedContext
        self._meta = _meta
    }
}

public struct ACPMCPCapabilities: ACPWireDefault {
    public static var acpDefault: Self { Self() }

    @ACPDefault public var http: Bool
    @ACPDefault public var sse: Bool
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(http: Bool = false, sse: Bool = false, _meta: ACPMeta? = nil) {
        self.http = http
        self.sse = sse
        self._meta = _meta
    }
}

public struct ACPCapability: Codable, Equatable, Sendable {
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(_meta: ACPMeta? = nil) {
        self._meta = _meta
    }
}

public typealias ACPSessionListCapabilities = ACPCapability
public typealias ACPSessionDeleteCapabilities = ACPCapability
public typealias ACPSessionAdditionalDirectoriesCapabilities = ACPCapability
public typealias ACPSessionResumeCapabilities = ACPCapability
public typealias ACPSessionCloseCapabilities = ACPCapability
public typealias ACPLogoutCapabilities = ACPCapability

public struct ACPSessionCapabilities: ACPWireDefault {
    public static var acpDefault: Self { Self() }

    @ACPDefaultOnError public var list: ACPCapability?
    @ACPDefaultOnError public var delete: ACPCapability?
    @ACPDefaultOnError public var additionalDirectories: ACPCapability?
    @ACPDefaultOnError public var resume: ACPCapability?
    @ACPDefaultOnError public var close: ACPCapability?
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(
        list: ACPCapability? = nil,
        delete: ACPCapability? = nil,
        additionalDirectories: ACPCapability? = nil,
        resume: ACPCapability? = nil,
        close: ACPCapability? = nil,
        _meta: ACPMeta? = nil
    ) {
        self.list = list
        self.delete = delete
        self.additionalDirectories = additionalDirectories
        self.resume = resume
        self.close = close
        self._meta = _meta
    }
}

public struct ACPAgentAuthCapabilities: ACPWireDefault {
    public static var acpDefault: Self { Self() }

    @ACPDefaultOnError public var logout: ACPCapability?
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(logout: ACPCapability? = nil, _meta: ACPMeta? = nil) {
        self.logout = logout
        self._meta = _meta
    }
}

public struct ACPAgentCapabilities: ACPWireDefault {
    public static var acpDefault: Self { Self() }

    @ACPDefault public var loadSession: Bool
    @ACPDefault public var promptCapabilities: ACPPromptCapabilities
    @ACPDefault public var mcpCapabilities: ACPMCPCapabilities
    @ACPDefault public var sessionCapabilities: ACPSessionCapabilities
    @ACPDefault public var auth: ACPAgentAuthCapabilities
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(
        loadSession: Bool = false,
        promptCapabilities: ACPPromptCapabilities = .acpDefault,
        mcpCapabilities: ACPMCPCapabilities = .acpDefault,
        sessionCapabilities: ACPSessionCapabilities = .acpDefault,
        auth: ACPAgentAuthCapabilities = .acpDefault,
        _meta: ACPMeta? = nil
    ) {
        self.loadSession = loadSession
        self.promptCapabilities = promptCapabilities
        self.mcpCapabilities = mcpCapabilities
        self.sessionCapabilities = sessionCapabilities
        self.auth = auth
        self._meta = _meta
    }
}
