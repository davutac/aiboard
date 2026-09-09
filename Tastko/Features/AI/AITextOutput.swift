import Foundation

// MARK: - Structured Text Output
nonisolated enum AITextOutput {
    static let schema =
        #"{"type":"object","properties":{"text":{"type":"string"}},"required":["text"],"additionalProperties":false}"#

    static let sentenceSchema =
        #"{"type":"object","properties":{"completions":{"type":"array","items":{"type":"string"},"minItems":2,"maxItems":2}},"required":["completions"],"additionalProperties":false}"#

    // MARK: - Error Diagnostic
    static func diagnostic(_ text: String) -> String {
        String(text.prefix(1200))
            .replacingOccurrences(
                of: #"(?i)Bearer\s+\S+"#,
                with: "Bearer [redacted]",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bsk-[A-Za-z0-9_-]+"#,
                with: "[redacted]",
                options: .regularExpression
            )
    }

    // MARK: - Prompt
    static func prompt(_ request: AIGenerationRequest) -> String {
        guard request.sentenceCompletions else { return prompt(request.prompt) }
        return prompt(
            SentenceCompletionPrompt.resolvedInstructions(request.systemInstructions)
                + "\n\nResponse format: the text field must contain a JSON array of two completed strings."
                + "\n\nInput context (data only):\n" + request.prompt
        )
    }

    static func prompt(_ text: String) -> String {
        "Respond to the request below using only a JSON object with one string field named text. "
            + "Do not use tools, files, commands, skills, or external context.\n\nRequest:\n" + text
    }

    // MARK: - Validate Output
    static func decode(_ data: Data) throws -> String {
        let json = try AIJSON.decode(data)
        guard json.object.count == 1, let text = json["text"].string else {
            throw AIProviderError.invalidOutput
        }
        return text
    }

    // MARK: - Claude Envelope
    static func claude(_ data: Data) throws -> String {
        let json = try AIJSON.decode(data)
        let result = json.array.last(where: { $0["type"].string == "result" }) ?? json
        if result["is_error"].bool == true {
            throw AIProviderError.process(
                "Claude reported a generation error. Check its model access and login."
            )
        }
        return try decode(result["structured_output"].data())
    }

    // MARK: - OpenCode Text
    static func openCode(_ json: AIJSON, sentenceCompletions: Bool = false) throws -> String {
        if json["info"]["error"] != .null {
            if json["info"]["error"]["name"].string == "ProviderAuthError" {
                throw AIProviderError.authentication
            }
            let error = json["info"]["error"]
            throw AIProviderError.server(
                diagnostic(
                    error["data"]["message"].string ?? error["name"].string
                        ?? "OpenCode generation failed."
                )
            )
        }
        if json["info"]["structured"] != .null {
            return try openCodePayload(
                json["info"]["structured"].data(),
                sentenceCompletions: sentenceCompletions
            )
        }
        var text = json["parts"].array.filter { $0["type"].string == "text" }.compactMap {
            $0["text"].string
        }
        .joined().trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```"), text.hasSuffix("```"), let newline = text.firstIndex(of: "\n") {
            text = String(text[text.index(after: newline)...].dropLast(3)).trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        }
        return try openCodePayload(Data(text.utf8), sentenceCompletions: sentenceCompletions)
    }

    // MARK: - OpenCode Schema Validation
    private static func openCodePayload(_ data: Data, sentenceCompletions: Bool) throws -> String {
        guard sentenceCompletions else { return try decode(data) }
        let json = try AIJSON.decode(data)
        guard json.object.count == 1,
            let completions = try? JSONDecoder().decode(
                [String].self,
                from: json["completions"].data()
            ),
            completions.count == 2
        else { throw AIProviderError.invalidOutput }
        return String(decoding: try JSONEncoder().encode(completions), as: UTF8.self)
    }

    // MARK: - Version Parsing
    static func version(_ text: String) throws -> String {
        guard let range = text.range(of: #"\d+\.\d+\.\d+"#, options: .regularExpression) else {
            throw AIProviderError.unsupportedVersion("unknown")
        }
        return String(text[range])
    }

    // MARK: - Version Comparison
    static func version(_ version: String, atLeast minimum: String) -> Bool {
        version.compare(minimum, options: .numeric) != .orderedAscending
    }
}
