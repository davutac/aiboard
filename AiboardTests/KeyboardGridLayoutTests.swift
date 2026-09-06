import CoreGraphics
import Testing

@testable import Aiboard

// MARK: - KeyboardGridLayoutTests
struct KeyboardGridLayoutTests {
    // MARK: - Rects
    @Test func rectUsesRelativeGridPlacement() {
        let layout = KeyboardGridLayout(columns: 64, rows: 5)
        let rect = layout.rect(
            for: KeyboardGridPlacement(
                column: 32,
                row: 2,
                columnSpan: 16,
                rowSpan: 1
            ),
            in: CGSize(width: 640, height: 220)
        )

        #expect(rect == CGRect(x: 320, y: 88, width: 160, height: 44))
    }

    @Test func rectScalesWithCanvasSize() {
        let layout = KeyboardGridLayout(columns: 64, rows: 5)
        let rect = layout.rect(
            column: 32,
            row: 2,
            columnSpan: 16,
            rowSpan: 1,
            in: CGSize(width: 1_280, height: 440)
        )

        #expect(rect == CGRect(x: 640, y: 176, width: 320, height: 88))
    }

    @Test func defaultLetterKeyIsSquareAtBaseSize() {
        let layout = KeyboardGridLayout(
            columns: KeyboardLayoutDefaults.gridColumns,
            rows: KeyboardLayoutDefaults.gridRows
        )
        let rect = layout.rect(
            column: 6,
            row: 1,
            columnSpan: 4,
            rowSpan: 1,
            in: KeyboardLayoutDefaults.baseSize
        )

        #expect(rect.width == rect.height)
    }

    @Test func lastRowRectReachesCanvasBottom() {
        let layout = KeyboardGridLayout(
            columns: KeyboardLayoutDefaults.gridColumns,
            rows: KeyboardLayoutDefaults.gridRows
        )
        let rect = layout.rect(
            column: 0,
            row: KeyboardLayoutDefaults.gridRows - 1,
            columnSpan: 1,
            rowSpan: 1,
            in: CGSize(width: 1_000, height: 260)
        )

        #expect(rect.maxY == 260)
    }

    // MARK: - Dragging
    @Test func snappedPositionRoundsDragToNearestGridCell() {
        let layout = KeyboardGridLayout(columns: 64, rows: 5)
        let position = layout.snappedPosition(
            startColumn: 10,
            startRow: 1,
            translation: CGSize(width: 15, height: 30),
            canvasSize: CGSize(width: 640, height: 220),
            columnSpan: 4,
            rowSpan: 1
        )

        #expect(position == KeyboardGridPosition(column: 12, row: 2))
    }

    @Test func snappedPositionClampsKeyInsideGrid() {
        let layout = KeyboardGridLayout(columns: 64, rows: 5)
        let position = layout.snappedPosition(
            startColumn: 60,
            startRow: 4,
            translation: CGSize(width: 100, height: 100),
            canvasSize: CGSize(width: 640, height: 220),
            columnSpan: 8,
            rowSpan: 1
        )

        #expect(position == KeyboardGridPosition(column: 56, row: 4))
    }
}
