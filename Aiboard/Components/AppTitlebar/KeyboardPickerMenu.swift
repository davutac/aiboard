import SwiftUI

// MARK: - KeyboardPickerMenu
struct KeyboardPickerMenu: View {
    let keyboards: [KeyboardModel]
    let selectedKeyboard: KeyboardModel?
    let selectKeyboard: (KeyboardModel) -> Void

    // MARK: - Body
    var body: some View {
        Menu {
            ForEach(sortedKeyboards, id: \.id) { keyboard in
                Button {
                    selectKeyboard(keyboard)
                } label: {
                    Label(
                        keyboard.name,
                        systemImage: isSelected(keyboard)
                            ? "checkmark"
                            : "keyboard"
                    )
                }
            }
        } label: {
            Label(title, systemImage: "keyboard")
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
        }
        .disabled(keyboards.isEmpty)
        .help("Keyboard layout")
    }

    // MARK: - Keyboards
    private var sortedKeyboards: [KeyboardModel] {
        keyboards.sorted { first, second in
            if first.sortIndex != second.sortIndex {
                return first.sortIndex < second.sortIndex
            }

            return first.name.localizedStandardCompare(second.name) == .orderedAscending
        }
    }

    private func isSelected(_ keyboard: KeyboardModel) -> Bool {
        selectedKeyboard.map { $0.id == keyboard.id } == true
    }

    // MARK: - Text
    private var title: String {
        selectedKeyboard?.name ?? "Keyboard"
    }
}
