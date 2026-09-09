import Foundation
import Testing

@testable import Tastko

// MARK: - Provider Protocol Tests
struct AIProviderTests {
    // MARK: - Codex Model Capabilities
    @Test func codexModelsPreserveUnknownReasoningAndDefaults() throws {
        let page = try AIJSON.decode(
            Data(
                #"{"data":[{"model":"future-model","displayName":"Future","isDefault":true,"supportedReasoningEfforts":[{"reasoningEffort":"new-effort"}],"defaultReasoningEffort":"new-effort"}]}"#
                    .utf8
            )
        )
        let model = try #require(CodexAIProvider.models(page).first)
        #expect(model.id == "future-model")
        #expect(model.isDefault)
        #expect(model.option?.choices.first?.id == "new-effort")
        #expect(model.option?.defaultValue == "new-effort")
    }

    // MARK: - OpenCode Inventory
    @Test func openCodeOnlyListsConnectedProvidersAndEnabledVariants() throws {
        let inventory = try AIJSON.decode(
            Data(
                #"{"connected":["local"],"default":{"local":"model"},"all":[{"id":"local","models":{"model":{"name":"Model","variants":{"high":{},"hidden":{"disabled":true}}}}},{"id":"disconnected","models":{"other":{}}}]}"#
                    .utf8
            )
        )
        let models = OpenCodeAIProvider.models(inventory)
        #expect(models.count == 1)
        #expect(models.first?.id == "local/model")
        #expect(models.first?.option?.choices.map(\.id) == ["high"])
        #expect(models.first?.isDefault == true)
    }

    // MARK: - Claude Catalog Compatibility
    @Test func claudeCatalogFiltersVersionsAndMapsEffort() throws {
        let data = Data(
            #"[{"model":{"id":"old","name":"Old","isDefault":false} ,"minimumVersion":"2.1.9"},{"model":{"id":"new","name":"New","isDefault":true},"minimumVersion":"2.1.100"}]"#
                .utf8
        )
        #expect(try ClaudeModelCatalog.decode(data, version: "2.1.20").map(\.id) == ["old"])
        let model = AIModelDescriptor(
            id: "claude-test",
            name: "Test",
            option: AIOptionDescriptor(
                id: "effort",
                name: "Reasoning",
                choices: [AIOptionChoice(id: "max", name: "Max", argument: "high")]
            )
        )
        let args = try ClaudeAIProvider.arguments(
            selection: AIProviderSelection(provider: .claude, modelID: model.id, optionID: "max"),
            model: model
        )
        #expect(args.contains("--no-session-persistence"))
        let index = try #require(args.firstIndex(of: "--effort"))
        #expect(args[index + 1] == "high")
        #expect(args.contains("--strict-mcp-config"))
        #expect(args[try #require(args.firstIndex(of: "--tools")) + 1] == "")
    }

    // MARK: - Structured Outputs
    @Test func whitespaceAndClaudeEnvelopeArePreserved() throws {
        #expect(try AITextOutput.decode(Data(#"{"text":" hello\n "}"#.utf8)) == " hello\n ")
        #expect(
            try AITextOutput.claude(
                Data(
                    #"[{"type":"system"},{"type":"result","structured_output":{"text":" OK "}}]"#
                        .utf8
                )
            ) == " OK "
        )
        #expect(throws: AIProviderError.invalidOutput) {
            try AITextOutput.decode(Data(#"{"text":7}"#.utf8))
        }
        #expect(throws: AIProviderError.invalidOutput) {
            try AITextOutput.decode(Data(#"{"text":"ok","extra":true}"#.utf8))
        }
        let response = try AIJSON.decode(
            Data(
                #"{"info":{},"parts":[{"type":"reasoning","text":"ignore"},{"type":"text","text":"```json\n{\"text\":\" OK \"}\n```"}]}"#
                    .utf8
            )
        )
        #expect(try AITextOutput.openCode(response) == " OK ")
    }

    @Test func openCodeDecodesNativeStructuredOutput() throws {
        let response = try AIJSON.decode(
            Data(
                #"{"info":{"structured":{"completions":["I want to rest.","I want to walk."]}},"parts":[]}"#
                    .utf8
            )
        )
        let text = try AITextOutput.openCode(response, sentenceCompletions: true)
        #expect(
            try JSONDecoder().decode([String].self, from: Data(text.utf8)) == [
                "I want to rest.", "I want to walk.",
            ]
        )
        let generic = try AIJSON.decode(
            Data(#"{"info":{"structured":{"text":" OK "}},"parts":[]}"#.utf8)
        )
        #expect(try AITextOutput.openCode(generic) == " OK ")
        #expect(throws: AIProviderError.invalidOutput) {
            try AITextOutput.openCode(generic, sentenceCompletions: true)
        }
    }

    // MARK: - Prompt and Option Forwarding
    @Test func openCodeKeepsProviderModelAndVariantIdentifiers() throws {
        let body = try OpenCodeAIProvider.promptBody(
            request: AIGenerationRequest(prompt: "input"),
            selection: AIProviderSelection(
                provider: .opencode,
                modelID: "provider/nested/model",
                optionID: "custom-variant"
            )
        )
        #expect(body["model"]["providerID"].string == "provider")
        #expect(body["model"]["modelID"].string == "nested/model")
        #expect(body["variant"].string == "custom-variant")
        #expect(body["format"]["type"].string == "json_schema")
        #expect(body["format"]["schema"]["properties"]["text"]["type"].string == "string")
        #expect(body["parts"].array.first?["text"].string?.hasSuffix("input") == true)
    }

    @Test func openCodeSentenceRequestsUseArraySchemaAndCustomSystemInstructions() throws {
        let body = try OpenCodeAIProvider.promptBody(
            request: AIGenerationRequest(
                prompt: "context",
                sentenceCompletions: true,
                systemInstructions: "Keep it brief."
            ),
            selection: AIProviderSelection(provider: .opencode, modelID: "provider/model")
        )
        #expect(body["format"]["schema"]["properties"]["completions"]["type"].string == "array")
        #expect(body["system"].string?.contains("Keep it brief.") == true)
        #expect(body["parts"].array.first?["text"].string == "context")
    }

    @Test func openCodeFallsBackOnlyForUnsupportedRequiredToolChoice() throws {
        let response = try AIJSON.decode(
            Data(
                #"{"info":{"error":{"data":{"message":"[invalid_request_error] only \"auto\" is supported for tool_choice"}}}}"#
                    .utf8
            )
        )
        #expect(OpenCodeAIProvider.requiresAutomaticToolChoice(response))
        #expect(!OpenCodeAIProvider.requiresAutomaticToolChoice(.object([:])))
        let body = try OpenCodeAIProvider.promptBody(
            request: AIGenerationRequest(prompt: "context", sentenceCompletions: true),
            selection: AIProviderSelection(provider: .opencode, modelID: "provider/model"),
            structuredOutput: false
        )
        #expect(body["format"]["type"].string == "text")
        #expect(body["system"].string?.contains(AITextOutput.sentenceSchema) == true)
        let output = try AIJSON.decode(
            Data(
                #"{"info":{},"parts":[{"type":"text","text":"{\"completions\":[\"I want to rest.\",\"I want to walk.\"]}"}]}"#
                    .utf8
            )
        )
        #expect(
            try AITextOutput.openCode(output, sentenceCompletions: true).contains("I want to rest.")
        )
    }

    // MARK: - Codex Restrictions
    @Test func codexArgumentsDisableConfiguredIntegrations() throws {
        let args = try CodexAIProvider.arguments(
            selection: AIProviderSelection(provider: .codex, modelID: "model", optionID: "low"),
            schema: URL(filePath: "/tmp/schema"),
            output: URL(filePath: "/tmp/output"),
            mcpNames: ["custom-server"]
        )
        #expect(args.contains("features.shell_tool=false"))
        #expect(args.contains("mcp_servers.custom-server.enabled=false"))
        #expect(args.contains("model_reasoning_effort=\"low\""))
        #expect(args.last == "-")
    }

    // MARK: - Executable Resolution
    @Test func missingOverrideNeverFallsBack() throws {
        #expect(throws: AIProviderError.executableNotFound("Codex")) {
            try AIExecutableResolver.resolve(
                .codex,
                override: "/does/not/exist",
                environment: ["PATH": "/opt/homebrew/bin"]
            )
        }
        #expect(
            try AIExecutableResolver.resolve(.claude, override: "/bin/echo", environment: [:])
                == "/bin/echo"
        )
        #expect(throws: AIProviderError.executableNotFound("Claude Code")) {
            try AIExecutableResolver.resolve(.claude, override: "/tmp", environment: [:])
        }
    }
}
