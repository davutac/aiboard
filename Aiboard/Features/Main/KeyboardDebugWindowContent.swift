import SwiftUI

// MARK: - KeyboardDebugWindowContent
struct KeyboardDebugWindowContent: View {
    let hide: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Button("Close", systemImage: "xmark") {
                    hide()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .accessibilityLabel("Close keyboard debug")
                .help("Close keyboard debug")

                Text("Keyboard Debug")
                    .font(.headline)
                    .lineLimit(1)

                Spacer(minLength: 12)
            }
            .padding(.horizontal, 12)
            .frame(height: AppConstants.titlebarHeight)
            .overlay(alignment: .bottom) {
                Divider()
            }

            KeyboardDebugView(showsHeader: false)
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(.regularMaterial)
        .clipShape(.rect(cornerRadius: 16))
        .ignoresSafeArea(.container, edges: .top)
    }
}
