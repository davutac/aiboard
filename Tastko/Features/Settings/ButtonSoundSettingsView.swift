import Defaults
import SwiftUI
import UniformTypeIdentifiers

// MARK: - ButtonSoundSettingsView
struct ButtonSoundSettingsView: View {
    @Default(.buttonSound) private var buttonSound
    @Default(.customButtonSound) private var customButtonSound
    @Environment(\.soundService) private var soundService
    @State private var isChoosingFile = false
    @State private var importError: String?

    // MARK: - Body
    var body: some View {
        Section("Sounds") {
            Picker("Button sound", selection: $buttonSound) {
                Text(ButtonSound.none.title).tag(ButtonSound.none)
                Text(ButtonSound.keyClick.title).tag(ButtonSound.keyClick)

                Section("Mechanical switches") {
                    ForEach(ButtonSound.mechanicalSwitches, id: \.self) { sound in
                        Text(sound.title).tag(sound)
                    }
                }

                if customButtonSound != nil {
                    Section {
                        Text(ButtonSound.custom.title).tag(ButtonSound.custom)
                    }
                }
            }

            if buttonSound == .custom, let customButtonSound {
                LabeledContent("Sound file", value: customButtonSound.displayName)
            }

            HStack {
                Button("Choose sound file…", systemImage: "folder") {
                    isChoosingFile = true
                }

                Button("Preview sound", systemImage: "speaker.wave.2") {
                    soundService.play(.keyPress)
                }
                .disabled(buttonSound == .none)
            }
        }
        .fileImporter(
            isPresented: $isChoosingFile,
            allowedContentTypes: [.audio],
            onCompletion: importSound
        )
        .alert(
            "Couldn’t import sound",
            isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "Choose a different audio file.")
        }
    }

    // MARK: - Import
    private func importSound(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            try soundService.importButtonSound(from: url)
        }
        catch {
            importError = error.localizedDescription
        }
    }
}
