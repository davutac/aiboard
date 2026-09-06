import SwiftData
import SwiftUI

// MARK: - KeyEditorPopover
struct KeyEditorPopover: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var key: KeyModel
    @Binding var selectedActionSlot: KeyActionSlot
    let languageContext: KeyboardLanguageContext

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            KeyEditorDivider()

            keyDetailsSection

            KeyEditorDivider()

            sizeSection

            KeyEditorDivider()

            behaviorSection
        }
        .padding(18)
        .frame(width: Self.popoverWidth)
        .onChange(of: key.title) {
            save()
        }
        .onChange(of: key.secondaryTitle) {
            save()
        }
        .onChange(of: key.labelKindRawValue) {
            save()
        }
        .onChange(of: key.labelSymbolName) {
            save()
        }
        .onChange(of: key.pressBehavior) {
            save()
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.accentColor.opacity(0.16))

                Image(systemName: "keyboard")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text("Key Settings")
                    .font(.title3.weight(.semibold))

                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Key Details
    private var keyDetailsSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionTitle("Key")

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
                editorRow("Display") {
                    KeySettingsDisplayPreview(resolvedKey: resolvedKey)
                }

                editorRow("Label") {
                    Picker("Label", selection: $key.labelKind) {
                        ForEach(KeyLabelKind.allCases, id: \.self) { kind in
                            Text(kind.displayTitle).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                switch key.labelKind {
                case .text:
                    editorRow("Title") {
                        TextField("Title", text: $key.title)
                            .textFieldStyle(.roundedBorder)
                    }
                case .symbol:
                    editorRow("Symbol") {
                        TextField("Symbol", text: $key.labelSymbolName)
                            .textFieldStyle(.roundedBorder)
                    }

                    editorRow("Name") {
                        TextField("Name", text: $key.title)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                editorRow("Secondary") {
                    TextField("Secondary", text: $key.secondaryTitle)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .controlSize(.large)
        }
    }

    // MARK: - Size
    private var sizeSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionTitle("Size")

            HStack(spacing: 12) {
                KeySpanField(
                    title: "Width",
                    value: widthSpanBinding,
                    range: widthSpanRange
                )

                KeySpanField(
                    title: "Height",
                    value: heightSpanBinding,
                    range: heightSpanRange
                )
            }
            .controlSize(.large)
        }
    }

    // MARK: - Behavior
    private var behaviorSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionTitle("Behavior")

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
                editorRow("Press") {
                    Picker("Press", selection: $key.pressBehavior) {
                        ForEach(KeyPressBehavior.allCases, id: \.self) { behavior in
                            Text(behavior.displayTitle).tag(behavior)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                editorRow("Action") {
                    Picker("Action", selection: $selectedActionSlot) {
                        ForEach(KeyActionSlot.allCases, id: \.self) { slot in
                            Text(slot.displayTitle).tag(slot)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }
            .controlSize(.large)

            KeyActionEditor(
                action: actionBinding(for: selectedActionSlot),
                languageContext: languageContext
            )
                .padding(.top, 1)
        }
    }

    // MARK: - Styling
    private var headerSubtitle: String {
        guard !resolvedKey.title.isEmpty else {
            return resolvedKey.labelKind == .symbol ? resolvedSymbolName : "Untitled key"
        }

        return resolvedKey.title
    }

    private var resolvedSymbolName: String {
        guard !resolvedKey.labelSymbolName.isEmpty else {
            return "questionmark"
        }

        return resolvedKey.labelSymbolName
    }

    private var resolvedKey: ResolvedKeyPresentation {
        LanguageAwareKeyResolver.presentation(
            title: key.title,
            secondaryTitle: key.secondaryTitle,
            labelKind: key.labelKind,
            labelSymbolName: key.labelSymbolName,
            leftClickAction: key.leftClickAction,
            rightClickAction: key.rightClickAction,
            languageContext: languageContext
        )
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private func editorRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        GridRow(alignment: .center) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: Self.rowLabelWidth, alignment: .leading)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Bindings
    private var widthSpanBinding: Binding<Int> {
        Binding {
            clamped(key.gridColumnSpan, to: widthSpanRange)
        } set: { span in
            key.gridColumnSpan = clamped(span, to: widthSpanRange)
            save()
        }
    }

    private var heightSpanBinding: Binding<Int> {
        Binding {
            clamped(key.gridRowSpan, to: heightSpanRange)
        } set: { span in
            key.gridRowSpan = clamped(span, to: heightSpanRange)
            save()
        }
    }

    private func actionBinding(for slot: KeyActionSlot) -> Binding<KeyAction> {
        Binding {
            switch slot {
            case .leftClick:
                key.leftClickAction
            case .rightClick:
                key.rightClickAction
            }
        } set: { action in
            switch slot {
            case .leftClick:
                key.leftClickAction = action
            case .rightClick:
                key.rightClickAction = action
            }

            save()
        }
    }

    // MARK: - Size Limits
    private var widthSpanRange: ClosedRange<Int> {
        1...maximumWidthSpan
    }

    private var heightSpanRange: ClosedRange<Int> {
        1...maximumHeightSpan
    }

    private var maximumWidthSpan: Int {
        max(1, keyboardGridColumns - key.gridColumn)
    }

    private var maximumHeightSpan: Int {
        max(1, keyboardGridRows - key.gridRow)
    }

    private var keyboardGridColumns: Int {
        max(1, key.keyboard?.gridColumns ?? KeyboardLayoutDefaults.gridColumns)
    }

    private var keyboardGridRows: Int {
        max(1, key.keyboard?.gridRows ?? KeyboardLayoutDefaults.gridRows)
    }

    // MARK: - Actions
    private func save() {
        try? modelContext.save()
    }

    // MARK: - Clamping
    private func clamped(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    // MARK: - Metrics
    private static let popoverWidth: CGFloat = 400
    private static let rowLabelWidth: CGFloat = 82
}

// MARK: - KeyEditorDivider
private struct KeyEditorDivider: View {
    // MARK: - Body
    var body: some View {
        Divider()
            .opacity(0.62)
    }
}

// MARK: - KeySettingsDisplayPreview
private struct KeySettingsDisplayPreview: View {
    let resolvedKey: ResolvedKeyPresentation

    // MARK: - Body
    var body: some View {
        HStack(spacing: 8) {
            primaryLabel

            if let secondaryTitle = resolvedKey.secondaryTitle {
                Text(secondaryTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.secondary.opacity(0.12), in: .rect(cornerRadius: 6))
            }
        }
        .frame(minHeight: 28, alignment: .leading)
    }

    // MARK: - Label
    @ViewBuilder
    private var primaryLabel: some View {
        switch resolvedKey.labelKind {
        case .text:
            Text(resolvedKey.title.isEmpty ? "Key" : resolvedKey.title)
                .font(.body.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.primary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.16), in: .rect(cornerRadius: 6))
        case .symbol:
            Image(systemName: resolvedSymbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.16), in: .rect(cornerRadius: 6))
        }
    }

    private var resolvedSymbolName: String {
        guard !resolvedKey.labelSymbolName.isEmpty else {
            return "questionmark"
        }

        return resolvedKey.labelSymbolName
    }
}

// MARK: - KeySpanField
private struct KeySpanField: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 7) {
                TextField(title, value: $value, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .monospacedDigit()
                    .frame(width: 58)

                Stepper(title, value: $value, in: range)
                    .labelsHidden()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - KeyActionSlot
enum KeyActionSlot: String, CaseIterable, Hashable, Sendable {
    case leftClick
    case rightClick

    // MARK: - Display
    var displayTitle: String {
        switch self {
        case .leftClick:
            "Left Click"
        case .rightClick:
            "Right Click"
        }
    }
}

// MARK: - KeyPressBehavior Display
extension KeyPressBehavior {
    var displayTitle: String {
        switch self {
        case .pressAndRelease:
            "Press"
        case .oneShot:
            "One Shot"
        }
    }
}
