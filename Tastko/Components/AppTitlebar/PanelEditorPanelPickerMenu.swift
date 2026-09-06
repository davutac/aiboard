import AppKit
import SwiftUI

// MARK: - PanelEditorPanelPickerMenu
struct PanelEditorPanelPickerMenu: View {
    let profiles: [PanelEditorProfile]
    let selectedPanel: PanelEditorPanel?
    let selectPanel: (PanelEditorPanel) -> Void
    let reload: () -> Void

    // MARK: - Body
    var body: some View {
        Menu {
            ForEach(profiles) { profile in
                Section(profile.displayName) {
                    ForEach(profile.panels) { panel in
                        Button {
                            selectPanel(panel)
                        } label: {
                            Label(
                                panel.name,
                                systemImage: isSelected(panel) ? "checkmark" : "rectangle.3.group"
                            )
                        }
                    }
                }
            }

            Divider()

            Button("Open Panel Editor", systemImage: "square.and.pencil") {
                openPanelEditor()
            }

            Button("Reload Panel Editor Profiles", systemImage: "arrow.clockwise") {
                reload()
            }
        } label: {
            Text(selectedPanel?.name ?? "No Profile")
                .lineLimit(1)
        }
        .menuIndicator(.hidden)
        .help("Switch profile")
    }

    // MARK: - Panel Editor
    private func openPanelEditor() {
        let workspace = NSWorkspace.shared
        let applicationURL =
            workspace.urlForApplication(
                withBundleIdentifier: "com.apple.AssistiveControl.editor"
            )
            ?? URL(
                filePath:
                    "/System/Library/Input Methods/Assistive Control.app/Contents/Resources/Panel Editor.app"
            )

        Task {
            do {
                _ = try await workspace.openApplication(
                    at: applicationURL,
                    configuration: NSWorkspace.OpenConfiguration()
                )
            }
            catch {
                NSApp.presentError(error)
            }
        }
    }

    // MARK: - Selection
    private func isSelected(_ panel: PanelEditorPanel) -> Bool {
        selectedPanel?.id == panel.id
    }
}
