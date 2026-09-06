import SwiftData
import SwiftUI

// MARK: - KeyboardEditView
struct KeyboardEditView: View {
    @Bindable var keyboard: KeyboardModel

    @Environment(\.modelContext) private var modelContext

    let windowSize: CGSize
    let minimumWindowSize: CGSize
    let resizeWindow: (CGSize) -> Void

    // MARK: - Body
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                Label("Window", systemImage: "macwindow")
                    .font(.headline)
                    .labelStyle(.titleAndIcon)
                    .fixedSize()

                Divider()
                    .frame(height: 22)

                KeyboardDimensionField(
                    title: "W",
                    value: windowWidthBinding,
                    range: windowWidthRange,
                    step: Self.sizeStep
                )

                KeyboardDimensionField(
                    title: "H",
                    value: windowHeightBinding,
                    range: windowHeightRange,
                    step: Self.sizeStep
                )

                Divider()
                    .frame(height: 22)

                Label("Grid", systemImage: "square.grid.3x3")
                    .font(.headline)
                    .labelStyle(.titleAndIcon)
                    .fixedSize()

                Divider()
                    .frame(height: 22)

                KeyboardIntegerField(
                    title: "Cols",
                    value: columnsBinding,
                    range: minimumGridColumns...Self.maximumGridColumns
                )

                KeyboardIntegerField(
                    title: "Rows",
                    value: rowsBinding,
                    range: minimumGridRows...Self.maximumGridRows
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(height: Self.toolbarHeight)
        .scrollIndicators(.hidden)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: - Bindings
    private var windowWidthBinding: Binding<Double> {
        Binding {
            Double(resolvedWindowSize.width)
        } set: { width in
            resizeWindow(
                CGSize(
                    width: CGFloat(clamped(width, to: windowWidthRange)),
                    height: resolvedWindowSize.height
                )
            )
        }
    }

    private var windowHeightBinding: Binding<Double> {
        Binding {
            Double(resolvedWindowSize.height)
        } set: { height in
            resizeWindow(
                CGSize(
                    width: resolvedWindowSize.width,
                    height: CGFloat(clamped(height, to: windowHeightRange))
                )
            )
        }
    }

    private var columnsBinding: Binding<Int> {
        Binding {
            keyboard.gridColumns
        } set: { columns in
            keyboard.gridColumns = clamped(columns, to: minimumGridColumns...Self.maximumGridColumns)
            save()
        }
    }

    private var rowsBinding: Binding<Int> {
        Binding {
            keyboard.gridRows
        } set: { rows in
            keyboard.gridRows = clamped(rows, to: minimumGridRows...Self.maximumGridRows)
            save()
        }
    }

    // MARK: - Limits
    private var minimumGridColumns: Int {
        max(
            Self.minimumGridColumns,
            keyboard.keys.map { key in
                key.gridColumn + key.gridColumnSpan
            }.max() ?? Self.minimumGridColumns
        )
    }

    private var minimumGridRows: Int {
        max(
            Self.minimumGridRows,
            keyboard.keys.map { key in
                key.gridRow + key.gridRowSpan
            }.max() ?? Self.minimumGridRows
        )
    }

    private var windowWidthRange: ClosedRange<Double> {
        Double(minimumWindowSize.width)...Self.maximumWindowWidth
    }

    private var windowHeightRange: ClosedRange<Double> {
        Double(minimumWindowSize.height)...Self.maximumWindowHeight
    }

    private var resolvedWindowSize: CGSize {
        windowSize.validWindowConstraint(fallback: minimumWindowSize)
    }

    // MARK: - Actions
    private func save() {
        try? modelContext.save()
    }

    // MARK: - Clamping
    private func clamped(_ value: Double, to range: ClosedRange<Double>) -> Double {
        guard value.isFinite else {
            return range.lowerBound
        }

        return min(max(value, range.lowerBound), range.upperBound)
    }

    private func clamped(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private static let maximumWindowWidth = 2_400.0
    private static let maximumWindowHeight = 1_200.0
    private static let sizeStep = 20.0
    private static let toolbarHeight: CGFloat = 38
    private static let minimumGridColumns = 1
    private static let minimumGridRows = 1
    private static let maximumGridColumns = 160
    private static let maximumGridRows = 24
}

// MARK: - KeyboardDimensionField
private struct KeyboardDimensionField: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    // MARK: - Body
    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)

            TextField(title, value: $value, format: .number.precision(.fractionLength(0)))
                .textFieldStyle(.roundedBorder)
                .monospacedDigit()
                .frame(width: 64)

            Stepper(title, value: $value, in: range, step: step)
                .labelsHidden()
        }
        .fixedSize()
    }
}

// MARK: - KeyboardIntegerField
private struct KeyboardIntegerField: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    // MARK: - Body
    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .trailing)

            TextField(title, value: $value, format: .number)
                .textFieldStyle(.roundedBorder)
                .monospacedDigit()
                .frame(width: 48)

            Stepper(title, value: $value, in: range)
                .labelsHidden()
        }
        .fixedSize()
    }
}
