import Foundation

public struct ACPInitializeRequest: Codable, Equatable, Sendable {
    public let protocolVersion: UInt16
    @ACPDefault public var clientCapabilities: ACPClientCapabilities
    @ACPDefaultOnError public var clientInfo: ACPImplementationInfo?
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(
        protocolVersion: UInt16 = ACPProtocol.version,
        clientCapabilities: ACPClientCapabilities = .acpDefault,
        clientInfo: ACPImplementationInfo? = nil,
        _meta: ACPMeta? = nil
    ) {
        self.protocolVersion = protocolVersion
        self.clientCapabilities = clientCapabilities
        self.clientInfo = clientInfo
        self._meta = _meta
    }
}

public struct ACPInitializeResponse: Codable, Equatable, Sendable {
    public let protocolVersion: UInt16
    @ACPDefault public var agentCapabilities: ACPAgentCapabilities
    @ACPDefaultLossyArray public var authMethods: [ACPAuthMethod]
    @ACPDefaultOnError public var agentInfo: ACPImplementationInfo?
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(
        protocolVersion: UInt16,
        agentCapabilities: ACPAgentCapabilities = .acpDefault,
        authMethods: [ACPAuthMethod] = [],
        agentInfo: ACPImplementationInfo? = nil,
        _meta: ACPMeta? = nil
    ) {
        self.protocolVersion = protocolVersion
        self.agentCapabilities = agentCapabilities
        self.authMethods = authMethods
        self.agentInfo = agentInfo
        self._meta = _meta
    }
}
