import AppKit
import SwiftUI

// MARK: - Settings Window Configuration
struct SettingsWindowConfiguration: NSViewRepresentable {
    // MARK: - View Creation
    func makeNSView(context: Context) -> WindowView { WindowView() }

    // MARK: - View Update
    func updateNSView(_ nsView: WindowView, context: Context) {}

    // MARK: - Window Attachment
    final class WindowView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            // Settings applies its expanded preference toolbar after attaching the content.
            DispatchQueue.main.async { [weak window] in
                window?.toolbarStyle = .unifiedCompact
            }
        }
    }
}
