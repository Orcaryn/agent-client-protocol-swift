import Foundation

public struct ACPProcessLaunch: Equatable, Sendable {
    public let executableURL: URL
    public let arguments: [String]
    public let environment: [String: String]
    public let workingDirectoryURL: URL?

    public init(
        executableURL: URL,
        arguments: [String] = [],
        environment: [String: String] = [:],
        workingDirectoryURL: URL? = nil
    ) {
        self.executableURL = executableURL
        self.arguments = arguments
        self.environment = environment
        self.workingDirectoryURL = workingDirectoryURL
    }
}
