import Foundation
import Testing

@testable import Tastko

// MARK: - Codex Transport Tests
struct AICodexTransportTests {
    // MARK: - Fixture Executable
    private func fixture() throws -> (URL, String) {
        let directory = try AIWorkspace.create()
        let file = directory.appending(path: "codex-fixture")
        let script = #"""
            #!/usr/bin/python3
            import json,sys
            if 'mcp' in sys.argv:
                print('[]')
            elif sys.argv[1] == 'exec':
                assert '--ephemeral' in sys.argv
                assert 'read-only' in sys.argv
                assert sys.argv[sys.argv.index('--model')+1] == 'fixture-1'
                assert 'model_reasoning_effort="low"' in sys.argv
                assert 'hello fixture' in sys.stdin.read()
                json.dump({'text':' fixture output '},open(sys.argv[sys.argv.index('--output-last-message')+1],'w'))
            else:
                for line in sys.stdin:
                    req=json.loads(line)
                    method=req.get('method')
                    if method=='initialized': continue
                    if method=='initialize': result={'userAgent':'codex/0.153.4'}
                    elif method=='account/read': result={'account':{'type':'chatgpt'}}
                    elif method=='model/list':
                        second=req['params'].get('cursor')=='next'
                        result={'data':[{'model':'fixture-2' if second else 'fixture-1','supportedReasoningEfforts':[{'reasoningEffort':'low'}]}],'nextCursor':None if second else 'next'}
                    else: raise Exception('Unexpected request')
                    print(json.dumps({'id':req['id'],'result':result}),flush=True)
            """#
        try Data(script.utf8).write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: file.path)
        return (directory, file.path)
    }

    // MARK: - Paginated Discovery
    @Test func discoveryCompletesHandshakeAndReadsEveryPage() async throws {
        let (directory, executable) = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let result = try await CodexAIProvider().discover(
            executable: executable,
            environment: ["PATH": "/usr/bin:/bin"]
        )
        #expect(result.models.map(\.id) == ["fixture-1", "fixture-2"])
        #expect(result.authentication == .authenticated)
        #expect(result.version == "0.153.4")
    }

    // MARK: - One-Shot Generation
    @Test func generationForwardsPromptAndParsesOutputFile() async throws {
        let (directory, executable) = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let result = try await CodexAIProvider().generate(
            request: AIGenerationRequest(prompt: "hello fixture"),
            selection: AIProviderSelection(provider: .codex, modelID: "fixture-1", optionID: "low"),
            model: AIModelDescriptor(id: "fixture-1", name: "Fixture"),
            executable: executable,
            environment: ["PATH": "/usr/bin:/bin"]
        )
        #expect(result == " fixture output ")
    }
}
