import ACPModel

/// An immutable view of the client state tracked for an established ACP session.
public struct ACPSessionSnapshot: Equatable, Sendable {
    public let roots: [String]
    public let modes: ACPSessionModeState?
    public let configOptions: [ACPSessionConfigOption]?
    public let plan: ACPPlan?
}
