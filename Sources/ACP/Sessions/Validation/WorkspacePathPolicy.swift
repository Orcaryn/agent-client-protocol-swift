import ACPModel
import Foundation

enum WorkspacePathPolicy {
    static func requireAbsolute(_ path: String) throws {
        guard !path.isEmpty, (path as NSString).isAbsolutePath else {
            throw ACPJSONRPCError.invalidParams
        }
    }

    static func require(_ path: String, within roots: [String]) throws {
        try requireAbsolute(path)
        guard !roots.isEmpty else { throw ACPJSONRPCError.resourceNotFound }

        let candidate = canonicalComponents(path)
        guard roots.contains(where: { candidate.starts(with: canonicalComponents($0)) }) else {
            throw ACPJSONRPCError.invalidParams
        }
    }

    private static func canonicalComponents(_ path: String) -> [String] {
        URL(fileURLWithPath: path)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .pathComponents
    }
}
