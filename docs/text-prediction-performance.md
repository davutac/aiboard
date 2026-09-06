# Text prediction performance

Run the optimized provider benchmark with fixed English and German examples:

```sh
bash script/benchmark_predictions.sh
```

Use `bash script/benchmark_predictions.sh --native-only` to measure the native service without invoking Foundation Models.

It reports native partial-word and next-word, first valid AI suggestion, and full model response median/p95 latency separately, prints the fixed sample outputs for quality inspection, and reports model unavailability instead of fabricating timings. Model measurements exclude the 150 ms debounce and the one-second prewarming allowance. They do not measure Accessibility capture or guarantee production end-to-end latency.

For actual field-capture timings, launch a Release build and inspect the `PredictionTiming` log category while typing in a disposable document:

```sh
AIBOARD_BUILD_CONFIGURATION=Release ./script/build_and_run.sh --verify
log stream --level debug --style compact --predicate 'subsystem == "com.davutcaliskan.Aiboard" AND category == "PredictionTiming"'
```

These timing records contain only stage names and elapsed milliseconds. Targets are native suggestions within 100 ms of detecting an edit and warm AI suggestions within 700 ms of the last edit. Measure on the target Mac; Foundation Models latency depends on model readiness and system load. To run unit tests optimized, add `-configuration Release ENABLE_TESTABILITY=YES` to the test command above.

Measured locally on September 5, 2026 with Xcode 27 beta 6 and optimized builds:

| Stage | Samples | Median | p95 |
| --- | ---: | ---: | ---: |
| Accessibility context capture, running Release app | 241 | 5.75 ms | 13.82 ms |
| Native candidates, fixed English/German partial words | 20 | 3.1 ms | 13.0 ms |
| Native candidates, fixed English/German next words | 20 | 1.6 ms | 2.0 ms |
| First valid prewarmed AI suggestion | 7 | 481.8 ms | 932.7 ms |
| Full prewarmed model response | 8 | 633.4 ms | 1160.4 ms |

Native timings were remeasured after adopting the candidate API; context and AI measurements are from the earlier provider benchmark with unchanged context capture and model generation. AI timings exclude the 150 ms debounce. One of eight model samples returned no valid prefix completion and is excluded from the first-valid timing. These small samples show fast native completion, but the 700 ms AI target is not consistently met; first-valid p95 plus debounce is approximately 1083 ms. Context capture and provider benchmarks were measured separately, not as end-to-end edit-to-display timings. Completion insertion and retained external-app focus were checked in TextEdit, Chrome, and a VS Code Insiders scratch editor.
