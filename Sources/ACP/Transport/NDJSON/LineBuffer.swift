import ACPModel

import Foundation

package struct ACPLineBufferResult {
    package let lines: [Data]
    package let exceededMaximum: Bool
}

package struct ACPLineBuffer {
    private var data = Data()
    private let maximumFrameBytes: Int

    package init(maximumFrameBytes: Int) {
        precondition(maximumFrameBytes > 0, "maximumFrameBytes must be positive")
        self.maximumFrameBytes = maximumFrameBytes
    }

    package mutating func append(_ chunk: Data) -> ACPLineBufferResult {
        data.append(chunk)
        var lines: [Data] = []
        var lineStart = data.startIndex

        while let newline = data[lineStart...].firstIndex(of: 0x0A) {
            let line = Data(data[lineStart..<newline])
            guard line.count <= maximumFrameBytes else {
                data.removeAll(keepingCapacity: false)
                return ACPLineBufferResult(lines: lines, exceededMaximum: true)
            }
            lines.append(line)
            lineStart = data.index(after: newline)
        }

        if lineStart != data.startIndex {
            data.removeSubrange(data.startIndex..<lineStart)
        }

        if data.count > maximumFrameBytes {
            data.removeAll(keepingCapacity: false)
            return ACPLineBufferResult(lines: lines, exceededMaximum: true)
        }

        return ACPLineBufferResult(lines: lines, exceededMaximum: false)
    }

    package mutating func takeRemainder() -> Data? {
        guard !data.isEmpty else {
            return nil
        }

        defer { data.removeAll(keepingCapacity: false) }
        return data
    }

    package static func isBlank(_ line: some DataProtocol) -> Bool {
        line.allSatisfy { $0 == 0x0D || $0 == 0x20 || $0 == 0x09 }
    }
}
