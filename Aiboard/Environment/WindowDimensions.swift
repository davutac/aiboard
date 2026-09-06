import CoreGraphics
import Observation

// MARK: - WindowDimensions
@Observable
@MainActor
final class WindowDimensions {
    static let environmentDefault = WindowDimensions()

    var size: CGSize = .zero
    var minSize: CGSize = .zero
    var maxSize: CGSize = .zero
    var isLiveResizing = false

    var width: CGFloat { size.width }
    var height: CGFloat { size.height }
    var minWidth: CGFloat { minSize.width }
    var minHeight: CGFloat { minSize.height }

    var currentScale: CGFloat {
        guard minWidth > 0, minHeight > 0 else { return 0 }

        let widthScale = width / minWidth
        let heightScale = height / minHeight

        guard widthScale.isFinite, heightScale.isFinite else { return 0 }

        return min(widthScale, heightScale)
    }

    var aspectRatio: CGFloat {
        guard height > 0 else { return 0 }

        return width / height
    }

    // MARK: - Update
    func update(size: CGSize, minSize: CGSize, maxSize: CGSize) {
        self.size = size
        self.minSize = minSize
        self.maxSize = maxSize
    }

    func updateLiveResizing(_ isLiveResizing: Bool) {
        self.isLiveResizing = isLiveResizing
    }
}
