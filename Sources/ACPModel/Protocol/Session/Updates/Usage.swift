import Foundation

public struct ACPCost: Codable, Equatable, Sendable {
    public let amount: Double
    public let currency: String
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(amount: Double, currency: String, _meta: ACPMeta? = nil) {
        self.amount = amount
        self.currency = currency
        self._meta = _meta
    }
}

public struct ACPUsageUpdate: Codable, Equatable, Sendable {
    public let used: UInt64
    public let size: UInt64
    @ACPDefaultOnError public var cost: ACPCost?
    @ACPDefaultOnError public var _meta: ACPMeta?

    public init(used: UInt64, size: UInt64, cost: ACPCost? = nil, _meta: ACPMeta? = nil) {
        self.used = used
        self.size = size
        self.cost = cost
        self._meta = _meta
    }
}
