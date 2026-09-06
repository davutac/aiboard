import CoreGraphics
import Testing

@testable import Tastko

// MARK: - FloatingWindowDefaultsTests
struct FloatingWindowDefaultsTests {
    // MARK: - Mini Size
    @Test func sanitizedMiniSizeLocksToSquare() {
        let size = FloatingWindowDefaults.sanitizedMiniSize(
            CGSize(width: 80, height: 120)
        )

        #expect(size == CGSize(width: 120, height: 120))
    }

    @Test func sanitizedMiniSizeClampsToAllowedRange() {
        let undersized = FloatingWindowDefaults.sanitizedMiniSize(
            CGSize(width: 20, height: 20)
        )
        let oversized = FloatingWindowDefaults.sanitizedMiniSize(
            CGSize(width: 400, height: 400)
        )

        #expect(undersized == FloatingWindowDefaults.minimumMiniSize)
        #expect(oversized == FloatingWindowDefaults.maximumMiniSize)
    }

    @Test func minimumMiniSizeMatchesButtonAndPadding() {
        let sideLength =
            FloatingWindowDefaults.miniButtonSideLength
            + (FloatingWindowDefaults.miniContentPadding * 2)

        #expect(
            FloatingWindowDefaults.minimumMiniSize
                == CGSize(
                    width: sideLength,
                    height: sideLength
                )
        )
    }

    @Test func sanitizedMiniSizeFallsBackForInvalidValues() {
        let size = FloatingWindowDefaults.sanitizedMiniSize(
            CGSize(width: CGFloat.nan, height: CGFloat.infinity)
        )

        #expect(size == FloatingWindowDefaults.defaultMiniSize)
    }
}
