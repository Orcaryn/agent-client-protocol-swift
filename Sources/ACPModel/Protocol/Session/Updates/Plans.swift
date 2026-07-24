import Foundation

public enum ACPPlanEntryPriority: String, Codable, Equatable, Sendable {
    case high
    case medium
    case low
}

public enum ACPPlanEntryStatus: String, Codable, Equatable, Sendable {
    case pending
    case inProgress = "in_progress"
    case completed
}

public struct ACPPlanEntry: Codable, Equatable, Sendable {
    public let content: String
    public let priority: ACPPlanEntryPriority
    public let status: ACPPlanEntryStatus
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(
        content: String,
        priority: ACPPlanEntryPriority,
        status: ACPPlanEntryStatus,
        _meta: ACPMeta? = nil
    ) {
        self.content = content
        self.priority = priority
        self.status = status
        self._meta = _meta
    }
}

public struct ACPPlan: Codable, Equatable, Sendable {
    @ACPRequiredLossyArray public var entries: [ACPPlanEntry]
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(entries: [ACPPlanEntry], _meta: ACPMeta? = nil) {
        self.entries = entries
        self._meta = _meta
    }
}
