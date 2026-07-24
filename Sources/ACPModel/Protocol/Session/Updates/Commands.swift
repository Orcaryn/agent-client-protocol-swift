import Foundation

public struct ACPAvailableCommandInput: Codable, Equatable, Sendable {
    public let hint: String
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(hint: String, _meta: ACPMeta? = nil) {
        self.hint = hint
        self._meta = _meta
    }
}

public struct ACPAvailableCommand: Codable, Equatable, Sendable {
    public let name: String
    public let description: String
    @ACPDefaultOnError public var input: ACPAvailableCommandInput?
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(
        name: String,
        description: String,
        input: ACPAvailableCommandInput? = nil,
        _meta: ACPMeta? = nil
    ) {
        self.name = name
        self.description = description
        self.input = input
        self._meta = _meta
    }
}

public struct ACPAvailableCommandsUpdate: Codable, Equatable, Sendable {
    @ACPRequiredLossyArray public var availableCommands: [ACPAvailableCommand]
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(availableCommands: [ACPAvailableCommand], _meta: ACPMeta? = nil) {
        self.availableCommands = availableCommands
        self._meta = _meta
    }
}
