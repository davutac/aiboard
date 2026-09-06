import CoreGraphics

// MARK: - CGSize Window Constraints
extension CGSize {
    nonisolated var isValidWindowConstraint: Bool {
        width.isFinite && height.isFinite && width > 0 && height > 0
    }

    // MARK: - Constraint
    nonisolated func validWindowConstraint(fallback: CGSize) -> CGSize {
        isValidWindowConstraint ? self : fallback
    }
}
