import SwiftData
import SwiftUI

// MARK: - KeyboardLayoutView
struct KeyboardLayoutView: View {
    @Environment(\.keyboardLanguageService) private var keyboardLanguageService

    let keyboard: KeyboardModel

    // MARK: - Body
    var body: some View {
        let languageContext = KeyboardLanguageContext(
            language: keyboardLanguageService.selectedLanguage
        )

        GeometryReader { proxy in
            let availableSize = proxy.size.validLayoutSize
            let layout = KeyboardGridLayout(
                columns: keyboard.gridColumns,
                rows: keyboard.gridRows
            )
            let canvasSize = availableSize

            ZStack(alignment: .topLeading) {
                ForEach(sortedKeys, id: \.id) { key in
                    KeyboardLayoutKeyView(
                        key: key,
                        layout: layout,
                        canvasSize: canvasSize,
                        languageContext: languageContext
                    )
                }
            }
            .frame(
                width: canvasSize.width,
                height: canvasSize.height,
                alignment: .topLeading
            )
            .contentShape(.rect)
            .frame(
                width: availableSize.width,
                height: availableSize.height,
                alignment: .topLeading
            )
        }
        .onAppear {
            keyboardLanguageService.refreshSelectedLanguage()
        }
    }

    // MARK: - Keys
    private var sortedKeys: [KeyModel] {
        keyboard.keys.sorted { first, second in
            if first.sortIndex != second.sortIndex {
                return first.sortIndex < second.sortIndex
            }

            if first.gridRow != second.gridRow {
                return first.gridRow < second.gridRow
            }

            return first.gridColumn < second.gridColumn
        }
    }
}

// MARK: - KeyboardLayoutKeyView
private struct KeyboardLayoutKeyView: View {
    @Environment(\.isKeyboardEditing) private var isKeyboardEditing
    @Environment(\.modelContext) private var modelContext

    let key: KeyModel
    let layout: KeyboardGridLayout
    let canvasSize: CGSize
    let languageContext: KeyboardLanguageContext

    @State private var dragTranslation = CGSize.zero
    @State private var isDragging = false

    // MARK: - Body
    var body: some View {
        let rect = layout.rect(for: placement, in: canvasSize)
        let frameSize = keyFrameSize(for: rect)
        let position = keyPosition(for: rect)

        KeyView(
            key: key,
            languageContext: languageContext,
            editingDragChanged: updateDrag,
            editingDragEnded: finishDrag
        )
        .frame(
            width: frameSize.width,
            height: frameSize.height
        )
        .position(
            x: position.x,
            y: position.y
        )
        .zIndex(isDragging ? 1 : 0)
        .animation(.smooth(duration: 0.12), value: key.gridColumn)
        .animation(.smooth(duration: 0.12), value: key.gridRow)
        .animation(.smooth(duration: 0.12), value: key.gridColumnSpan)
        .animation(.smooth(duration: 0.12), value: key.gridRowSpan)
        .onChange(of: isKeyboardEditing) {
            guard isKeyboardEditing else {
                cancelDrag()
                return
            }
        }
    }

    // MARK: - Dragging
    private var dragOffset: CGSize {
        guard isKeyboardEditing, isDragging else {
            return .zero
        }

        let currentRect = layout.rect(for: placement, in: canvasSize)
        let position = snappedPosition(for: dragTranslation)
        let snappedRect = layout.rect(
            column: position.column,
            row: position.row,
            columnSpan: key.gridColumnSpan,
            rowSpan: key.gridRowSpan,
            in: canvasSize
        )

        let offset = CGSize(
            width: snappedRect.minX - currentRect.minX,
            height: snappedRect.minY - currentRect.minY
        )

        return offset.isValidLayoutSize ? offset : .zero
    }

    private func updateDrag(_ translation: CGSize) {
        guard isKeyboardEditing, translation.isValidLayoutSize else {
            return
        }

        isDragging = true
        dragTranslation = translation
    }

    private func finishDrag(_ translation: CGSize) {
        guard isKeyboardEditing, translation.isValidLayoutSize else {
            cancelDrag()
            return
        }

        let position = snappedPosition(for: translation)

        key.gridColumn = position.column
        key.gridRow = position.row
        cancelDrag()
        try? modelContext.save()
    }

    private func cancelDrag() {
        isDragging = false
        dragTranslation = .zero
    }

    private func snappedPosition(for translation: CGSize) -> KeyboardGridPosition {
        layout.snappedPosition(
            startColumn: key.gridColumn,
            startRow: key.gridRow,
            translation: translation,
            canvasSize: canvasSize,
            columnSpan: key.gridColumnSpan,
            rowSpan: key.gridRowSpan
        )
    }

    // MARK: - Placement
    private var placement: KeyboardGridPlacement {
        KeyboardGridPlacement(
            column: key.gridColumn,
            row: key.gridRow,
            columnSpan: key.gridColumnSpan,
            rowSpan: key.gridRowSpan
        )
    }

    // MARK: - Layout
    private func keyFrameSize(for rect: CGRect) -> CGSize {
        guard rect.isValidLayoutRect else {
            return .zero
        }

        return CGSize(
            width: max(0, rect.width - KeyboardLayoutDefaults.keyGap),
            height: max(0, rect.height - KeyboardLayoutDefaults.keyGap)
        )
    }

    private func keyPosition(for rect: CGRect) -> CGPoint {
        guard rect.isValidLayoutRect else {
            return .zero
        }

        let dragOffset = dragOffset
        let position = CGPoint(
            x: rect.midX + dragOffset.width,
            y: rect.midY + dragOffset.height
        )

        return position.isValidLayoutPoint ? position : .zero
    }
}

// MARK: - Layout Validation
extension CGSize {
    fileprivate var validLayoutSize: CGSize {
        guard isValidLayoutSize else {
            return .zero
        }

        return self
    }

    fileprivate var isValidLayoutSize: Bool {
        width.isFinite && height.isFinite
    }
}

extension CGPoint {
    fileprivate var isValidLayoutPoint: Bool {
        x.isFinite && y.isFinite
    }
}

extension CGRect {
    fileprivate var isValidLayoutRect: Bool {
        origin.x.isFinite
            && origin.y.isFinite
            && size.width.isFinite
            && size.height.isFinite
            && size.width >= 0
            && size.height >= 0
    }
}
