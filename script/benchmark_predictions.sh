#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BENCHMARK_DIR="$ROOT_DIR/.build/PredictionBenchmark"
mkdir -p "$BENCHMARK_DIR"

xcrun swiftc -O -parse-as-library -target "$(uname -m)-apple-macos27.0" \
    "$ROOT_DIR/Tastko/Models/AccessibilityTextRange.swift" \
    "$ROOT_DIR/Tastko/Models/PredictionInput.swift" \
    "$ROOT_DIR/Tastko/Services/NativeWordPredictionProvider.swift" \
    "$ROOT_DIR/Tastko/Services/FoundationWordPredictionProvider.swift" \
    "$ROOT_DIR/script/benchmark_predictions.swift" \
    -o "$BENCHMARK_DIR/prediction-benchmark"

"$BENCHMARK_DIR/prediction-benchmark" "$@"
