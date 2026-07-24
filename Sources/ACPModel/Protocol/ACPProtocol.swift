import Foundation

public enum ACPProtocol {
    public static let version: UInt16 = 1

    public enum Method {
        public static let initialize = "initialize"
        public static let authenticate = "authenticate"
        public static let logout = "logout"
        public static let sessionNew = "session/new"
        public static let sessionLoad = "session/load"
        public static let sessionResume = "session/resume"
        public static let sessionList = "session/list"
        public static let sessionDelete = "session/delete"
        public static let sessionClose = "session/close"
        public static let sessionPrompt = "session/prompt"
        public static let sessionCancel = "session/cancel"
        public static let sessionSetMode = "session/set_mode"
        public static let sessionSetConfigOption = "session/set_config_option"
        public static let sessionUpdate = "session/update"
        public static let sessionRequestPermission = "session/request_permission"
        public static let fileSystemReadTextFile = "fs/read_text_file"
        public static let fileSystemWriteTextFile = "fs/write_text_file"
        public static let terminalCreate = "terminal/create"
        public static let terminalOutput = "terminal/output"
        public static let terminalWaitForExit = "terminal/wait_for_exit"
        public static let terminalKill = "terminal/kill"
        public static let terminalRelease = "terminal/release"
        public static let cancelRequest = "$/cancel_request"
    }
}

public typealias ACPMeta = [String: ACPValue]

public struct ACPEmptyResponse: Codable, Equatable, Sendable {
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(_meta: ACPMeta? = nil) {
        self._meta = _meta
    }
}
