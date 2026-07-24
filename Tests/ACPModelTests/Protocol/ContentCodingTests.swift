import Foundation
import Testing

@testable import ACPModel

struct ContentCodingTests {
    @Test func canonicalContentBlocksMatchWireSchema() throws {
        try expectCanonicalJSON(
            .text(
                ACPTextContent(
                    text: "hello",
                    annotations: ACPAnnotations(
                        audience: [.assistant, .user],
                        lastModified: "2026-07-12T12:00:00Z",
                        priority: 0.75
                    ),
                    _meta: ["trace": .string("content-1")]
                )
            ) as ACPContentBlock,
            #"{"type":"text","text":"hello","annotations":{"audience":["assistant","user"],"lastModified":"2026-07-12T12:00:00Z","priority":0.75},"_meta":{"trace":"content-1"}}"#
        )
        try expectCanonicalJSON(
            .image(ACPImageContent(data: "aW1hZ2U=", mimeType: "image/png", uri: "file:///image.png"))
                as ACPContentBlock,
            #"{"type":"image","data":"aW1hZ2U=","mimeType":"image/png","uri":"file:///image.png"}"#
        )
        try expectCanonicalJSON(
            .audio(ACPAudioContent(data: "YXVkaW8=", mimeType: "audio/wav")) as ACPContentBlock,
            #"{"type":"audio","data":"YXVkaW8=","mimeType":"audio/wav"}"#
        )
        try expectCanonicalJSON(
            .resourceLink(
                ACPResourceLink(
                    uri: "file:///README.md",
                    name: "README",
                    description: "Project documentation",
                    mimeType: "text/markdown",
                    size: 42,
                    title: "Read me"
                )
            ) as ACPContentBlock,
            #"{"type":"resource_link","uri":"file:///README.md","name":"README","description":"Project documentation","mimeType":"text/markdown","size":42,"title":"Read me"}"#
        )
        try expectCanonicalJSON(
            .resource(
                ACPEmbeddedResource(
                    resource: .text(
                        ACPTextResourceContents(
                            uri: "file:///notes.txt",
                            text: "notes",
                            mimeType: "text/plain"
                        )
                    )
                )
            ) as ACPContentBlock,
            #"{"type":"resource","resource":{"uri":"file:///notes.txt","text":"notes","mimeType":"text/plain"}}"#
        )
        try expectCanonicalJSON(
            .resource(
                ACPEmbeddedResource(
                    resource: .blob(
                        ACPBlobResourceContents(uri: "file:///data.bin", blob: "ZGF0YQ==")
                    )
                )
            ) as ACPContentBlock,
            #"{"type":"resource","resource":{"uri":"file:///data.bin","blob":"ZGF0YQ=="}}"#
        )
    }

    @Test func canonicalToolCallContentMatchesWireSchema() throws {
        try expectCanonicalJSON(
            .content(
                ACPContentToolCallContent(
                    content: .text(ACPTextContent(text: "running"))
                )
            ) as ACPToolCallContent,
            #"{"type":"content","content":{"type":"text","text":"running"}}"#
        )
        try expectCanonicalJSON(
            .diff(ACPDiffToolCallContent(path: "/tmp/file", oldText: "old", newText: "new")) as ACPToolCallContent,
            #"{"type":"diff","path":"/tmp/file","oldText":"old","newText":"new"}"#
        )
        try expectCanonicalJSON(
            .terminal(ACPTerminalToolCallContent(terminalID: "terminal-1")) as ACPToolCallContent,
            #"{"type":"terminal","terminalId":"terminal-1"}"#
        )
    }

    @Test func unknownFieldsAreIgnoredAndMetaIsPreserved() throws {
        let content = try decode(
            ACPContentBlock.self,
            #"{"type":"text","text":"hello","futureField":{"enabled":true},"_meta":{"trace":"abc","nested":{"count":2}}}"#
        )
        #expect(
            content
                == .text(
                    ACPTextContent(
                        text: "hello",
                        _meta: [
                            "trace": .string("abc"),
                            "nested": .object(["count": .integer(2)]),
                        ]
                    )
                )
        )
        try expectEncodedJSON(
            content,
            #"{"type":"text","text":"hello","_meta":{"trace":"abc","nested":{"count":2}}}"#
        )

        let malformedMeta = try decode(
            ACPTextContent.self,
            #"{"text":"hello","_meta":4,"future":true}"#
        )
        #expect(malformedMeta == ACPTextContent(text: "hello"))
    }

    @Test func schemaDefaultedOptionalFieldsIgnoreTypeMismatches() throws {
        let content = try decode(
            ACPTextContent.self,
            #"{"text":"hello","annotations":4}"#
        )
        #expect(content.annotations == nil)

        let request = try decode(
            ACPReadTextFileRequest.self,
            #"{"sessionId":"session-1","path":"README.md","line":"first"}"#
        )
        #expect(request.line == nil)
    }
}
