# AI providers

Settings → AI Providers configures Codex, Claude Code, OpenCode, and Apple Foundation Model. AI starts Off. Selecting one provider does not erase the other providers' model or reasoning/variant selections. This feature does not change word predictions or send text automatically.

Use the Active provider picker to select a provider or Off. The model and reasoning/variant menus remain editable for inactive providers. Each CLI provider’s Details button opens Refresh, executable selection, and installation/login instructions. Apple Foundation Model shows system availability and a Refresh button.

For Codex, Claude Code, and OpenCode, install and authenticate using the provider’s CLI. Tastko discovers executables from the user's login-shell PATH and common installation paths, with an optional explicit executable override. Status refreshes every five minutes while AI Providers settings are open; leaving the section stops periodic refresh. You can also refresh after signing in or updating a CLI. Discovery does not submit inference prompts.

Codex reports its models and reasoning levels through its app-server protocol. OpenCode reports connected upstream models and variants through its local HTTP server. Claude uses a bundled version-aware catalog adapted from T3 Code; the catalog is not a guarantee that the account can access every model. The bundled catalog includes CLI reasoning/thinking options, excluding agent orchestration modes and prompt-injected options. Its metadata and attribution live in `Tastko/Features/AI/ClaudeModelCatalog.json` and `T3Code-LICENSE.txt`.

Apple Foundation Model runs on-device through the macOS 27 Foundation Models framework and requires Apple Intelligence to be enabled and ready. Discovery uses `SystemLanguageModel.availability` and `capabilities`. Its system model is managed by macOS and selected automatically; reasoning choices appear only when `.reasoning` is supported. Each generation creates a fresh `LanguageModelSession`, uses `@Generable` for the structured text response and `ContextOptions` for reasoning, and disallows tools. It uses no CLI, login, or API key and does not share sessions with word predictions. Availability is checked again for each request. Framework failures are mapped from macOS 27’s `LanguageModelError`.

See Apple’s [Foundation Models overview](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models) and [ContextOptions](https://developer.apple.com/documentation/foundationmodels/contextoptions).

## Try a request in Debug

Open Settings → AI Providers, select an active provider and model, then open **AI Debug**. Enter text and click **Generate**. The view shows the complete response, provider/model/options, elapsed time, and errors. **Cancel** stops the request. Navigating away cancels an in-flight request. AI Debug is excluded from Release builds.

CLI requests use the provider’s existing account and may consume its usage allowance. Apple Foundation Model requests use the on-device model. Tastko does not save input or output. Provider software may maintain its own operational logs.

## App-internal API

Use the normal app's `AIProviderService` instance (owned by `AppDelegate`):

```swift
let result = try await service.generate(
    AIGenerationRequest(prompt: "Complete this sentence: Tomorrow I will")
)
// result.text preserves whitespace.
// result.selection identifies the provider/model/options captured at request start.
```

The default timeout is 180 seconds. Cancel the calling Swift task to cancel the request. Off, unavailable selections, authentication failures, timeout/cancellation, invalid output, and transport errors have distinct `AIProviderError` cases. No automatic retries or provider fallback occur. A nil option delegates to the provider default.

Codex and Claude run one-shot commands with JSON Schema output. OpenCode uses a temporary restricted session on a managed loopback server, with abort/delete cleanup and a 30-second server idle timeout. An unexpected OpenCode server exit releases its resources; the next request starts a replacement. Failed generations are never replayed. This API has no chat history, attachments, streaming, or tool callbacks.

## Persistence and migrations

`AppPersistence` owns the general app-wide `ModelContainer`. The local store is `Application Support/<bundle identifier>/Tastko.store`, keeping Debug and Release separate. Existing Defaults settings are unchanged.

`AppSchemaV1` contains `AISettings`, `AIProviderConfiguration`, and `AIModelCatalogCache`. Only selections, executable overrides, and catalog metadata are stored. Authentication status, prompts, outputs, and credentials are not stored. Changes are explicitly saved.

For future features, add a new `AppSchemaV2` rather than modifying V1. Include the new version in `AppMigrationPlan.schemas`, add the appropriate migration stage, and point the container at the new current schema. Test opening an actual V1 store with the new plan. An initialization failure must preserve the store; Retry never deletes data or switches to a silent in-memory replacement.

The login-window helper does not initialize app persistence or AI services.

## Developer diagnostics

Build Debug, then run the explicit command-line harness:

```sh
./script/build_and_run.sh build
LLVM_PROFILE_FILE=/tmp/tastko-ai-%p.profraw \
  '.build/DerivedData/Build/Products/Debug/Tastko Debug.app/Contents/MacOS/Tastko Debug' \
  --ai-diagnostics
```

Add `--generate` to send a small test prompt through authenticated CLI providers or the available Apple model. Add `--provider codex` (or `claude`, `opencode`, `apple`) to limit the run, and optionally `--model <model-id>` to explicitly select a model. Use `--prompt "hi how are you"` with `--generate` to test a custom request. The harness uses an in-memory store, leaves saved provider selections unchanged, and reports models/options plus timing. It is excluded from Release.

Source reference: [T3 Code short-generation adapters, commit 0fe4c99](https://github.com/pingdotgg/t3code/tree/0fe4c99ee6df4cbb7a9064d2d86ece65ecef5eb3/apps/server/src/textGeneration).

## Validation (2026-09-08)

- Debug and Release builds passed. The full TastkoTests target passed: 280 tests, zero failures or skipped tests, including existing keyboard/prediction tests and new persistence, discovery, process, and HTTP tests.
- Inspected the real macOS provider settings card and Debug tab. LaunchServices discovery found Codex 0.153.4, Claude Code 2.1.263, and OpenCode 1.18.29. Saved selections survived relaunch.
- Live developer harness: Codex `gpt-6-astra / low` returned `Tastko AI OK` in 7.28 seconds; OpenCode `openai/gpt-6-astra / low` returned the same text in 5.28 seconds.
- Live Debug view: Codex `gpt-5.6-luna / low` returned `Tastko debug view OK` in 3.85 seconds.
- Claude generation was not run because the installed CLI reported signed out. An OpenCode Copilot request reported its account quota error; the successful OpenAI request used an explicitly selected model, without automatic fallback.
- UI validation was manual; the automated UI test target was not run. The login-window entry path returns before creating the normal app delegate, persistence, or provider services.
