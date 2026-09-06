import Foundation
import OSLog

// MARK: - PredictionTiming
nonisolated enum PredictionTiming {
    private static let logger = Logger(
        subsystem: "com.davutcaliskan.Aiboard",
        category: "PredictionTiming"
    )

    // MARK: - Measurement
    static func record(_ stage: String, since start: ContinuousClock.Instant) {
        let elapsed = start.duration(to: .now).components
        let milliseconds = Double(elapsed.seconds) * 1_000 + Double(elapsed.attoseconds) / 1e15
        logger.debug("\(stage, privacy: .public) \(milliseconds, privacy: .public) ms")
    }
}
