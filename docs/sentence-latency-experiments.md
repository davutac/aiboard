# Sentence latency investigation — September 9, 2026

The baseline is commit `6df7518`, which already generates one sentence suggestion.
Experiments used Apple's on-device model on this Mac with Xcode 27 beta 6.
The latency work retained cached instruction/schema token counts, a shorter
default prompt, and initially one active sentence request at a time. A subsequent
interaction change allows two overlapping requests with a 250 ms throttle so newer
typing can start generating before an earlier request finishes. The sections below
report each comparison separately; provider generation and post-typing wait are
different measurements.

## Token-count cache

Three serial rounds of ten prompts per version, reversing execution order in the
middle round, produced these provider timings:

| Version | Requests | Median | p95 | Prefix/format checks |
| --- | ---: | ---: | ---: | ---: |
| Original single-suggestion provider | 30 | 883.3 ms | 1649.5 ms | 30/30 |
| Cached instruction/schema counts | 30 | 832.6 ms | 1584.9 ms | 30/30 |

The median improved by 50.7 ms, or 5.7%. Each round includes its first cache miss.
This is a modest improvement, not a demonstrated large or twofold speedup.
Generation still dominates latency. Model output length and system load introduce
variation; prefix/format results are not a general language-quality guarantee.

## Approaches tested

| Approach | Observation | Decision |
| --- | --- | --- |
| Generate only the new ending | Lower latency, but lost leading spaces and sometimes mishandled partial words | Rejected |
| Generate the last word and ending | Some responses omitted or changed the required word prefix | Rejected |
| Constrain that prefix with a regex | Enforced the prefix but still produced weak German grammar | Rejected |
| Omit the schema from the prompt; also try greedy sampling | Some long responses omitted the required input prefix; production-provider validation failed | Rejected |
| Prewarm instructions 1.2 seconds ahead | No consistent improvement in warm-model trials; this was not a cold-start test | Not added |
| Generate only the current sentence with earlier text as context | Substantial savings on long passages, but repeated German word-order errors and occasional duplication of earlier text | Rejected |
| Cache unchanged token counts | Removes repeated counting without changing model input or output | Retained |

Three direct token-counting probes took approximately 110–128 ms to count
instructions, input, and schema serially. Instructions and schema are stable
across typing requests. The cache shares in-flight work, counts those two values
concurrently on a miss, and retains only the latest instruction key and its
counts. It never caches typed text or generated output. Changing instructions
recounts; errors remain retryable; cancelling a consumer preserves shared work.

Prefix and format checks do not measure grammar. Manual output review found,
for example, `möchte ich besprechen die nächsten Schritte` in a faster variant,
where the baseline used normal German word order. Passing structural checks
alone was not sufficient to retain a change.

## Reproduce

Run `bash script/benchmark_sentences.sh`. The benchmark uses ten fixed samples:
short English/German fragments, partial words, and longer passages. It prints
generated text for inspection and separately counts usable prefix/format results.
Results include provider token counting and complete generation; they exclude
typing throttle, Accessibility capture, and UI presentation. They do not measure
continuous-typing contention or cold model loading.

Exploratory logs are saved locally under
`.build/verification/sentence-latency/`. Exploratory timings were used to identify
candidates; the final comparison runs baseline and retained implementation
serially, with alternating execution order.

## Parallel requests for multiple visible suggestions

A follow-up compared one, two, and three concurrent requests, each asking for one
completion in its own session. All results were retained. Three rounds of the same
ten prompts rotated execution order, using the current cached-count provider and
one unmeasured warm-up request. These timings measure completed provider responses;
they do not include the typing throttle, Accessibility, or UI rendering.

| Concurrent requests | Trials | Median first result | Median all results ready | Trials with the requested number of distinct results |
| --- | ---: | ---: | ---: | ---: |
| 1 | 30 | 810.1 ms | 810.1 ms | 30/30 |
| 2 | 30 | 865.5 ms | 1421.6 ms | 15/30 |
| 3 | 30 | 915.7 ms | 1949.9 ms | 5/30 |

All 180 responses passed prefix/format checks. These checks are not grammar checks:
one German response was `Ich möchte einen Kaffee zu bestellen.` Identical requests
frequently produced identical suggestions. For example, all three requests in one
trial returned `I want to explore the new features.` Exact-string deduplication
would leave fewer visible choices in half of the two-request trials and 25/30 of
the three-request trials.

Parallel requests could support progressive display: show the first result, then
append distinct alternatives. They do not make all suggestions arrive at the
single-request latency. The observed timing is consistent with shared inference
resources, but this experiment does not establish Apple's internal scheduling.
This is not a comparison against generating a two- or three-element array in one
request. This experiment did not change the production suggestion count or scheduling.

Reproduce with `bash script/benchmark_sentences.sh --parallel-all`. Output is JSONL
with first-result, individual completion, settlement timings, and generated text.
The harness waits for every request before starting the next trial. Raw results
are saved locally in `.build/verification/sentence-latency/parallel-all.jsonl`.

An earlier race-to-one experiment is available with `--parallel`: it cancels the
other requests after the first structurally valid result. Its first-result medians
were 881.5, 925.8, and 938.3 ms for one, two, and three requests respectively, across
30 trials each. That addresses racing for one suggestion, rather than displaying
multiple suggestions. Results are in `parallel-race.jsonl` beside the all-results
log. Both modes use separate sessions because Apple documents one active request
per session in [Generating content and performing tasks](https://developer.apple.com/documentation/FoundationModels/generating-content-and-performing-tasks-with-foundation-models).

## Shorter default system prompt

The retained prompt removes two sentences from the original: the instruction to
infer intended meaning despite typos and the repeated final self-check. Explicit
prefix preservation, partial-word handling, language/tone, optional word hints,
completion length, complete-thought guidance, and the example remain. User-supplied
custom prompts are unchanged. The default uses **245 instruction tokens instead
of 284 (13.7% fewer)** on this model.

Three rounds of ten standard prompts per version reversed execution order in the
middle round. Both versions used the token-count cache and one fresh session per
request; each process included its first cache miss. Measurements include prompt
token counting and full generation, excluding UI, Accessibility, and typing delay.

| Default instructions | Requests | Median | p95 | Prefix/format checks |
| --- | ---: | ---: | ---: | ---: |
| Original, 284 tokens | 30 | 839.7 ms | 1566.8 ms | 30/30 |
| Retained trim, 245 tokens | 30 | 804.2 ms | 1548.9 ms | 30/30 |

This is a **35.5 ms / 4.2% median improvement**, not a large speedup. Output length
also varied (median total output words 8.5 versus 8), so this is an end-to-end
prompt comparison, not an isolated measurement of input processing cost.

Five more aggressive candidates used 122, 169, 178, 226, and 234 tokens. Screening
found incomplete words, ellipses instead of a completed thought, extra sentences,
changed quotes, or weaker German grammar. None was retained. This does not prove
245 tokens is a global minimum; it is the conservative reduction supported by
this investigation.

### Broader quality checks and limits

A separate 16-case set ran three times per final version (48 outputs each). It
covers questions, subordinate clauses, typos, trailing whitespace, completed
sentences, command-like writing, third-person writing, quotes, and a newline.
The original passed prefix/nonempty-format checks on 42/48 outputs; the retained
trim passed 45/48. The improvement came from preserving `I realy want to` in all
three trials; the original corrected `realy`, which the service rejects.

Both versions replaced the newline in all three newline trials and incorrectly
added text to both already-complete sentences in every trial. Both also produced
incorrect German subordinate-clause word order. The trim occasionally produced
an extra sentence or incorrect question punctuation. Prefix/format checks do not
establish semantic quality, and the tests do not show these existing weaknesses
are solved. The service still rejects changed prefixes and displays at most one
suggestion.

### Reproduce the prompt comparison

`bash script/benchmark_sentences.sh` tests the current default. Add
`--instructions-file /absolute/path/to/prompt.txt` to test a candidate without
changing app settings. Add `--quality` for the 16 broader cases. This mode reports
instruction token counts and generated outputs; completed-sentence behavior needs
manual review even if a result passes the prefix/format check.

The local archive `.build/verification/sentence-latency/prompts/` contains every
candidate, screening logs, and the final three-round baseline/trim comparisons.
The baseline prompt is also available in commit `6df7518`. The shipped prompt was
checked byte-for-byte against the candidate used in the final comparison. All 434
unit tests and strict Swift formatting passed. The rebuilt Debug app launched
successfully, and its provider diagnostics generated an English partial-word
completion and a German sentence completion. These were provider integration
checks, not a new UI insertion test.

Apple recommends [short, clear instructions](https://developer.apple.com/documentation/foundationmodels/instructions)
and [iterating against actual outputs](https://developer.apple.com/documentation/foundationmodels/prompting-an-on-device-foundation-model).
Our results support trimming repetition, while showing why token count alone is
not enough to select a prompt.

## Scheduling while typing

The next change targets time spent waiting after typing, rather than isolated
model generation. The old default started requests at 500 ms intervals and allowed
five in flight. The v0.1.7 default allowed **one active sentence request** and starts
the latest queued input as soon as that request finishes, with no fixed throttle.
Intermediate input snapshots are coalesced. Matching earlier results still appear
immediately and remain usable while a refresh runs. Cancellation, focus checks,
custom prompt handling, and the one-suggestion display are preserved.

### Real-model typing replay

The benchmark compiles the actual sentence service and Apple provider. It replays
seven typed characters at 120 or 250 ms intervals into an observable context,
then measures until a valid suggestion is available for the final input. Focus
value declarations are taken from the app, but no real Accessibility capture is
performed. Availability is sampled at approximately 5 ms intervals after allowing
5 ms for the final Observation update. Word prediction and UI rendering are not
included; this is not a cold-start or full application latency measurement.

Initial screening used four English/German sequences, three rounds each, rotating
strategy order. A strategy that cancelled the current request and restarted every
200 ms performed worse: mean post-typing wait 901.0 ms, compared with 279.6 ms for
the old default and 175.7 ms for one active request. It launched 84 requests versus
40 and 33 respectively. Cancellation discarded progress that could have produced
a matching completion. Both retained/old policies had a zero median on this first
set because many completions were already usable when typing stopped.

Four different sequences were then tested three times per policy:

| Scheduling | Trials | Median wait after typing | Mean wait | Worst wait | Requests launched |
| --- | ---: | ---: | ---: | ---: | ---: |
| Old: 500 ms interval, up to five active | 12 | 694.9 ms | 729.0 ms | 1826.8 ms | 46 |
| New: one active, latest input next | 12 | 285.7 ms | 405.9 ms | 1276.7 ms | 36 |

The validation-set median improved **58.9%**, and the mean improved **44.3%**.
All 24 trials produced a structurally usable suggestion within the six-second
measurement window. These are small, fixed replay sets; neither a universal
speedup nor a grammar improvement is established. The prompt, schema, and model
options were identical between scheduling policies.

A final four-case check using the production implementation reproduced the
improvement: median 913.2 → 288.1 ms. Raw logs and the original experimental service
snapshots are saved under `.build/verification/sentence-latency/scheduling/`.

### Reproduce and validate

Run `bash script/benchmark_sentence_typing.sh` for the four validation sequences
and three rounds. Use `--rounds 1` for a smoke test or `--build-only` to compile the
harness without generating text. It compares explicit old scheduling parameters
with serial scheduling in the same service implementation and emits
JSONL with result text, post-typing wait, request count, and peak concurrency.

The unit suite includes serial coalescing, reuse while refreshing, and rejection
of results from an old focus target. All 437 tests passed. Strict Swift formatting,
shell syntax, Debug build/launch, and benchmark compilation passed. A live TextEdit
check showed one companion suggestion, `…for the meeting tomorrow?`, for
`Could you please confirm the date` in the rebuilt Debug app. This verified live
display, not a new timed UI benchmark or click-to-insert test.

## Subsequent interaction change

After v0.1.7, the requested interaction changed to allow overlapping generations
with a slight throttle. The default is now two requests in flight, with 250 ms
between starts. The single visible suggestion updates as each valid response
finishes, provided its request is newer than the last published request. A still
newer request may remain in flight. Older results cannot replace newer ones.

The serial-scheduling numbers above are historical measurements, not performance
claims for this new policy. `benchmark_sentence_typing.sh` retains explicit old
and serial parameters so those comparisons remain reproducible. The new behavior
is covered by request-ordering, bounded-overlap, coalescing, and throttle tests.
All 439 unit tests passed. A four-case real-model typing smoke test using the new
defaults observed two active requests and a usable suggestion in every case; the
Debug build and launch also passed. These checks do not establish a latency
improvement over serial generation.

## Apple references

- [Performance analysis and token consumption](https://developer.apple.com/documentation/foundationmodels/analyzing-the-runtime-performance-of-your-foundation-models-app)
- [Guided generation and schema constraints](https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation)
- [Session caching and prewarming](https://developer.apple.com/documentation/foundationmodels/optimizing-key-value-caching-in-language-model-sessions)

Apple explains that output length affects generation time and that schema
omission can reduce input processing when examples already define the format.
Those opportunities still need application-specific quality checks. Session
prewarming requires lead time; it does not make inference itself instantaneous.

## Text-only autocomplete prompt

The next simplification removes keyboard-language and native-word hints entirely.
The service sends the captured writing unchanged; the Apple provider puts it in a
single `text` field to distinguish writing from instructions and preserve quoted
text. No cursor metadata is sent. The default instructions ask for natural sentence
completion in the language of that text, with an explicit partial-word example.
The production prompt measures 126 tokens, down from 245 (49% fewer).

Three ten-sample runs per version on this Mac measured a median of 799.0 ms for
the previous provider/prompt and 750.4 ms for the new version, a 6.1% reduction.
Both passed prefix/format checks on 30/30 outputs. These are provider timings,
including token counting, not end-to-end typing/UI latency. Baseline runs were
collected during the candidate comparisons; the final three runs followed them,
so system load and sampling remain possible confounders. Do not add this percentage
to earlier experiments or treat it as a guaranteed speedup.

Screening unmarked raw text produced follow-up questions and only 4/10 usable
standard outputs. A simple label improved ordinary inputs but mishandled quotes
and command-like writing. A single text field preserved those boundaries without
restoring metadata. Short 153-token instructions repeatedly left `I wan` unfinished;
the retained autocomplete wording completed it as `I want` in all three final runs.
A longer 206-token variant did not resolve the remaining language-quality issues.

A 16-case quality screen of the retained wording (with a trailing newline in the
instructions file, measuring 127 tokens) passed prefix/format checks on 14/16:
the model corrected `realy` and removed an existing newline, so both are rejected
by the service. It still sometimes adds another sentence, adds to already-complete
text, or makes German grammar errors. The repeated standard runs also contained
some extra sentences and German article errors. This change simplifies input and
reduces measured latency; it does not solve these model-quality limitations.

The local `.build/verification/sentence-latency/text-only/` archive contains
candidate instructions, outputs, and the repeated comparisons. The service tests
verify exact writing reaches the provider, including quotes and newlines, alongside
result ordering and throttle behavior. The full suite passed 439 test runs after
the provider changes; focused sentence tests passed again with the final prompt,
and the rebuilt Debug app launched. Four synthetic typing cases using the real
Apple model all returned suggestions with peak concurrency two. These were model
integration checks, not live Accessibility insertion tests.
