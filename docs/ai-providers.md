# AI providers

Settings → AI Providers currently exposes Apple Foundation Model and Off. Codex,
Claude Code, and OpenCode are disabled and hidden because their latency is a poor
fit for live autocomplete. Their adapters, settings views, and saved model/options
remain in the codebase for later use. The service can explicitly opt back in with
`cliProvidersEnabled: true`; the app defaults to false.

On startup, a saved active CLI provider is migrated to Apple. An explicit Off
selection stays Off. Disabled providers cannot be selected, refreshed, or used for
generation by the default service, including developer diagnostics.

Apple Foundation Model runs on-device. With an active provider and text prediction
enabled, sentence completions begin while typing once at least three letters are
available. Requests contain up to 512 characters before the cursor. Word predictions
remain separate. Set the active provider to Off to disable sentence requests.

## Sentence completions

Settings → AI Providers → Sentence completion prompt contains a multiline editor.
Its placeholder shows the default instructions. Leave it empty (or whitespace-only)
to use the default; any other text replaces the instructions for all providers.
Changes save automatically in the app's preferences and cancel pending completions.
Use **Use default as starting point** to edit a copy, or **Reset to default** to clear
the override. Response schemas and exact-prefix insertion checks remain enforced.

Apple counts instruction, input, and response-schema tokens before generation.
Instructions are limited to the smaller of 1,024 tokens or one quarter of the
model's context size. The combined budget reserves output space for two copies
of the input plus their endings, and 256 tokens of headroom. Oversized requests
fail with a clear error; custom instructions are never silently truncated.
Settings displays the instruction token count and limit.

`SentenceCompletionPrompt.swift` owns the shared completion instructions. Typed
text is a separate JSON context payload, not part of the standing instructions.
It includes up to five currently available word suggestions for the same context,
sampled when generation starts. These are optional hints; generation never waits
for word predictions, and later word updates do not trigger another request.
Apple receives the instructions through `LanguageModelSession` and returns a
native `@Generable` array. OpenCode uses `format: json_schema` and decodes
`info.structured`, with a native completions array. Its session denies all tools
except the built-in `StructuredOutput` formatter. If an upstream model rejects
required tool choice (for example Muse 1.3), the adapter retries once in text mode
with the same JSON schema in the prompt and validates the result locally. Codex and Claude include the
same instructions in their restricted structured-text request. The prompt prioritizes exact prefix
preservation, the language of the writing, concise endings, and plausible
alternatives without replying to questions or inventing personal details. It infers
meaning despite typos while preserving the exact typed prefix.
Model quality still varies: prefix/format checks reject malformed output, but do
not guarantee grammar or semantic quality.

The child window shows a spinner before the clickable sentence continuations
in a Liquid Glass container. Loading and suggestions can remain visible together. Suggestions animate in unless Reduce
Motion is enabled. Suggestion buttons size to their current text. Requests have a 30-second timeout; failures show an error message
with full details on hover. Apart from that tool-choice compatibility retry, failures are not retried and
providers are never switched automatically.

Requests are throttled from their start time: 500 ms for Apple and two seconds
for CLI providers. Up to five requests run concurrently, each using the latest
context. A newer usable result cancels older requests, and late older results
cannot replace it. Each valid newer result appears immediately, even while later
requests are running. Failed or empty results preserve useful pending requests and any still-valid visible suggestions.
Cancelled requests retain their slot until they exit. Continued typing reuses matching endings and trims the typed prefix,
keeping valid suggestions visible during refresh. Edits, focus changes, selecting
text, shortcut modifiers, hiding/minimizing the keyboard, locking, or turning
predictions off invalidate pending suggestions.
Completions are requested only at the end of the text. Clicking revalidates the
full context and target and inserts only the new suffix, preserving existing text
and spacing. Typed context and generated completions are not persisted by Tastko; custom
system instructions are saved in preferences.

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

The default timeout is 180 seconds. Cancel the calling Swift task to cancel the request. Off, unavailable selections, authentication failures, timeout/cancellation, invalid output, and transport errors have distinct `AIProviderError` cases. No automatic retries or provider fallback occur. A nil option uses light reasoning for Apple models that support reasoning; other providers use their default.

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
