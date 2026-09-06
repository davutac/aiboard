import AppKit
import SwiftUI

// MARK: - MouseInteractiveHostingView
final class MouseInteractiveHostingView<Content: View>: NSHostingView<Content> {
    // MARK: - Mouse Events
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
