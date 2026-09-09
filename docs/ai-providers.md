# AI providers

Settings → AI Providers offers Apple Foundation Model and Off. Generation runs
on-device, without CLI executables, subprocesses, authentication, or provider servers.
A saved legacy provider selection switches to Apple on startup; Off stays Off.

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
native `@Generable` array. The prompt prioritizes exact prefix
preservation, the language of the writing, concise endings, and plausible
alternatives without replying to questions or inventing personal details. It infers
meaning despite typos while preserving the exact typed prefix.
Model quality still varies: prefix/format checks reject malformed output, but do
not guarantee grammar or semantic quality.

The child window shows a spinner before the clickable sentence continuations
in a Liquid Glass container. Loading and suggestions can remain visible together. Suggestions animate in unless Reduce
Motion is enabled. Suggestion buttons size to their current text. Requests have a 30-second timeout; failures show an error message
with full details on hover. Failures are not retried and
providers are never switched automatically.

Requests are throttled to 500 ms from their start time. Up to five requests run concurrently, each using the latest
context. A newer usable result cancels older requests, and late older results
cannot replace it. Each valid newer result appears immediately, even while later
requests are running. Failed or empty results preserve useful pending requests and any still-valid visible suggestions.
The last successful completion is cached in memory with its input, language, and
model selection. Returning to that input after a focus change or keyboard restart
restores the suggestions without a request. Changing the system prompt clears the
cache; different model options or input require generation. Nothing is written to disk.

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

Apple Foundation Model requests use the on-device model. Tastko does not save input or output.

## App-internal API

Use the normal app's `AIProviderService` instance (owned by `AppDelegate`):

```swift
let result = try await service.generate(
    AIGenerationRequest(prompt: "Complete this sentence: Tomorrow I will")
)
// result.text preserves whitespace.
// result.selection identifies the provider/model/options captured at request start.
```

The default timeout is 180 seconds. Cancel the calling Swift task to cancel the request. Off, unavailable selections, timeout/cancellation, invalid output, and model errors have distinct `AIProviderError` cases. No automatic retries or provider fallback occur. A nil option uses light reasoning when the model supports reasoning.

The API has no chat history, streaming, or tool callbacks.

## Persistence and migrations

`AppPersistence` owns the general app-wide `ModelContainer`. The local store is `Application Support/<bundle identifier>/Tastko.store`, keeping Debug and Release separate. Existing Defaults settings are unchanged.

`AppSchemaV1` contains `AISettings`, `AIProviderConfiguration`, and `AIModelCatalogCache`. Selections and catalog metadata are stored. Legacy executable-override and CLI-version fields remain in V1 for store compatibility; runtime code no longer reads executable overrides. Old provider rows are ignored. Prompts, outputs, and credentials are not stored in this schema. Changes are explicitly saved.

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

Add `--generate` to send a request through Apple. Optionally use `--provider apple`
and `--model system-default`. Use `--prompt "hi how are you"` to test custom input,
or `--sentence-completions` with a JSON context payload to test sentence endings.
The harness uses an in-memory store, leaves saved selections unchanged, and reports
the result and timing. It is excluded from Release.
