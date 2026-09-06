import CoreGraphics

// MARK: - KeyboardGridPosition
nonisolated struct KeyboardGridPosition: Equatable, Hashable, Sendable {
    let column: Int
    let row: Int
}

// MARK: - KeyboardGridPlacement
nonisolated struct KeyboardGridPlacement: Equatable, Hashable, Sendable {
    let column: Int
    let row: Int
    let columnSpan: Int
    let rowSpan: Int
}

// MARK: - KeyboardGridLayout
nonisolated struct KeyboardGridLayout: Equatable, Hashable, Sendable {
    let columns: Int
    let rows: Int

    // MARK: - Initialization
    init(columns: Int, rows: Int) {
        self.columns = max(1, columns)
        self.rows = max(1, rows)
    }

    // MARK: - Rects
    func rect(
        for placement: KeyboardGridPlacement,
        in canvasSize: CGSize
    ) -> CGRect {
        guard canvasSize.isValidWindowConstraint else {
            return .zero
        }

        let clampedPlacement = clamped(placement)
        let cellWidth = canvasSize.width / CGFloat(columns)
        let cellHeight = canvasSize.height / CGFloat(rows)
        let rect = CGRect(
            x: CGFloat(clampedPlacement.column) * cellWidth,
            y: CGFloat(clampedPlacement.row) * cellHeight,
            width: CGFloat(clampedPlacement.columnSpan) * cellWidth,
            height: CGFloat(clampedPlacement.rowSpan) * cellHeight
        )

        return rect.isValidLayoutRect ? rect : .zero
    }

    func rect(
        column: Int,
        row: Int,
        columnSpan: Int,
        rowSpan: Int,
        in canvasSize: CGSize
    ) -> CGRect {
        rect(
            for: KeyboardGridPlacement(
                column: column,
                row: row,
                columnSpan: columnSpan,
                rowSpan: rowSpan
            ),
            in: canvasSize
        )
    }

    // MARK: - Dragging
    func snappedPosition(
        startColumn: Int,
        startRow: Int,
        translation: CGSize,
        canvasSize: CGSize,
        columnSpan: Int,
        rowSpan: Int
    ) -> KeyboardGridPosition {
        let columnDelta = snappedDelta(
            translation: translation.width,
            canvasLength: canvasSize.width,
            divisions: columns
        )
        let rowDelta = snappedDelta(
            translation: translation.height,
            canvasLength: canvasSize.height,
            divisions: rows
        )

        return clampedPosition(
            column: startColumn + columnDelta,
            row: startRow + rowDelta,
            columnSpan: columnSpan,
            rowSpan: rowSpan
        )
    }

    func clampedPosition(
        column: Int,
        row: Int,
        columnSpan: Int,
        rowSpan: Int
    ) -> KeyboardGridPosition {
        let safeColumnSpan = clampedSpan(columnSpan, limit: columns)
        let safeRowSpan = clampedSpan(rowSpan, limit: rows)

        return KeyboardGridPosition(
            column: column.clamped(to: 0...(columns - safeColumnSpan)),
            row: row.clamped(to: 0...(rows - safeRowSpan))
        )
    }

    // MARK: - Placement
    private func clamped(_ placement: KeyboardGridPlacement) -> KeyboardGridPlacement {
        let columnSpan = clampedSpan(placement.columnSpan, limit: columns)
        let rowSpan = clampedSpan(placement.rowSpan, limit: rows)
        let position = clampedPosition(
            column: placement.column,
            row: placement.row,
            columnSpan: columnSpan,
            rowSpan: rowSpan
        )

        return KeyboardGridPlacement(
            column: position.column,
            row: position.row,
            columnSpan: columnSpan,
            rowSpan: rowSpan
        )
    }

    private func clampedSpan(_ span: Int, limit: Int) -> Int {
        span.clamped(to: 1...limit)
    }

    private func snappedDelta(
        translation: CGFloat,
        canvasLength: CGFloat,
        divisions: Int
    ) -> Int {
        guard canvasLength > 0, canvasLength.isFinite else {
            return 0
        }

        let cellLength = canvasLength / CGFloat(divisions)

        guard cellLength > 0, cellLength.isFinite else {
            return 0
        }

        return Int((translation / cellLength).rounded())
    }
}

// MARK: - CGRect Validation
private extension CGRect {
    nonisolated var isValidLayoutRect: Bool {
        origin.x.isFinite
            && origin.y.isFinite
            && size.width.isFinite
            && size.height.isFinite
            && size.width >= 0
            && size.height >= 0
    }
}

// MARK: - Int Clamp
private extension Int {
    nonisolated func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
