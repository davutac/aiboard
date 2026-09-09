import CoreGraphics
import Observation

// MARK: - WindowDimensions
@Observable
@MainActor
final class WindowDimensions {
    static let environmentDefault = WindowDimensions()

    var parentSize: CGSize = .zero
    var size: CGSize = .zero
}
