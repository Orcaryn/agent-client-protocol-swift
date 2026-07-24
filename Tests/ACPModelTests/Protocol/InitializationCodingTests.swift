import Foundation
import Testing

@testable import ACPModel

struct InitializationCodingTests {
    @Test func decodesCodexInitializeResponseWithExtensionFields() throws {
        let data = Data(
            #"{"protocolVersion":1,"agentCapabilities":{"loadSession":true,"mcpCapabilities":{"http":true,"sse":false,"acp":false},"auth":{"logout":{}}},"authMethods":[{"type":"env_var","id":"codex-api-key","name":"Use CODEX_API_KEY","vars":[{"name":"CODEX_API_KEY"}]}],"agentInfo":{"name":"codex-acp","title":"Codex","version":"0.16.0"}}"#
                .utf8
        )
        let response = try JSONDecoder().decode(ACPInitializeResponse.self, from: data)

        #expect(response.protocolVersion == 1)
        #expect(response.agentCapabilities.mcpCapabilities.http == true)
        #expect(response.authMethods.first?.id == "codex-api-key")
        #expect(response.agentInfo?.name == "codex-acp")
    }

    @Test func appliesInitializationDefaults() throws {
        let response = try JSONDecoder().decode(
            ACPInitializeResponse.self,
            from: Data(#"{"protocolVersion":1}"#.utf8)
        )
        #expect(response.agentCapabilities.loadSession == false)
        #expect(response.agentCapabilities.promptCapabilities.image == false)
        #expect(response.agentCapabilities.promptCapabilities.audio == false)
        #expect(response.agentCapabilities.promptCapabilities.embeddedContext == false)
        #expect(response.agentCapabilities.mcpCapabilities.http == false)
        #expect(response.agentCapabilities.mcpCapabilities.sse == false)
        #expect(response.authMethods == [])

        let request = try JSONDecoder().decode(
            ACPInitializeRequest.self,
            from: Data(#"{"protocolVersion":1}"#.utf8)
        )
        #expect(request.clientCapabilities.fs.readTextFile == false)
        #expect(request.clientCapabilities.fs.writeTextFile == false)
        #expect(request.clientCapabilities.terminal == false)
    }
}
