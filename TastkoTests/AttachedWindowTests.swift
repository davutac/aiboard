import AppKit
import Observation
import SwiftUI
import Testing

@testable import Tastko

// MARK: - Attached Window Tests
@Suite(.serialized)
@MainActor
struct AttachedWindowTests {
    // MARK: - Lifecycle and Geometry
    @Test func companionFollowsParentAndRestoresAfterDetaching() throws {
        let controller = AlwaysOnTopWindowController()
        var configuration = AlwaysOnTopWindowConfiguration(
            size: CGSize(width: 600, height: 280),
            minSize: CGSize(width: 100, height: 100),
            origin: CGPoint(x: 200, y: 200),
            maintainsContentAspectRatio: false
        )
        controller.show(configuration: configuration) { Color.clear }
        defer { controller.hide() }
        let parent = try #require(NSApp.windows.first { $0.frame == controller.frame })
        controller.showChild(ChildWindowID("test")) { Text("Companion test") }
        let child = try #require(parent.childWindows?.first)
        #expect(child.parent === parent)
        #expect(child.isVisible)
        #expect(!child.canBecomeKey)
        #expect(child.frame.minX == parent.frame.minX)
        #expect(child.frame.minY == parent.frame.maxY + 8)

        parent.setFrameOrigin(CGPoint(x: 300, y: 300))
        #expect(child.frame.minX == parent.frame.minX)
        #expect(child.frame.minY == parent.frame.maxY + 8)

        configuration.size = CGSize(width: 700, height: 320)
        controller.updateGeometry(configuration: configuration)
        #expect(child.frame.width == parent.frame.width)
        #expect(child.frame.minY == parent.frame.maxY + 8)

        controller.hideChild(ChildWindowID("test"))
        #expect(child.parent == nil)
        #expect(!child.isVisible)
        controller.showChild(ChildWindowID("test")) { Text("Companion test") }
        #expect(child.parent === parent)
        #expect(child.isVisible)
        #expect(child.frame.width == parent.frame.width)
        #expect(child.frame.minY == parent.frame.maxY + 8)
        controller.hide()
        #expect(!parent.isVisible)
        #expect(!child.isVisible)
    }
    // MARK: - Multiple Children and Updates
    @Test func childrenKeepIdentityAndIndependentVisibility() throws {
        let controller = AlwaysOnTopWindowController()
        let first = ChildWindowID("first")
        let second = ChildWindowID("second")
        controller.showChild(first) { Text("Created before parent") }
        #expect(!controller.isChildVisible(first))
        controller.show(
            configuration: .init(
                size: CGSize(width: 500, height: 250),
                origin: CGPoint(x: 150, y: 150)
            )
        ) { Color.clear }
        defer { controller.hide() }
        let parent = try #require(NSApp.windows.first { $0.frame == controller.frame })
        let original = try #require(parent.childWindows?.first)
        controller.showChild(
            second,
            configuration: .init(
                edge: .bottom,
                size: .fixed(CGSize(width: 200, height: 60))
            )
        ) { Text("Second") }
        #expect(parent.childWindows?.count == 2)
        controller.showChild(
            first,
            configuration: .init(
                title: "Updated",
                style: .init(hasShadow: false, opacity: 0.5),
                ignoresMouseEvents: true
            )
        ) { Text("Updated") }
        #expect(parent.childWindows?.contains(where: { $0 === original }) == true)
        #expect(original.title == "Updated")
        #expect(!original.hasShadow)
        #expect(original.alphaValue == 0.5)
        #expect(original.ignoresMouseEvents)
        controller.hideChild(first)
        #expect(!controller.isChildVisible(first))
        #expect(controller.isChildVisible(second))
        controller.hide()
        controller.show { Color.clear }
        #expect(!controller.isChildVisible(first))
        #expect(controller.isChildVisible(second))
        controller.removeChild(second)
        #expect(controller.childFrame(second) == nil)
        #expect(parent.childWindows?.isEmpty != false)
    }

    // MARK: - Placement
    @Test func placementResolvesEdgesAlignmentAndSizing() {
        let parent = CGRect(x: 100, y: 200, width: 400, height: 300)
        var configuration = ChildWindowConfiguration(
            size: .fixed(CGSize(width: 80, height: 40)),
            gap: 10
        )
        #expect(
            configuration.frame(relativeTo: parent) == CGRect(x: 260, y: 510, width: 80, height: 40)
        )
        configuration.edge = .bottom
        configuration.alignment = .end
        #expect(
            configuration.frame(relativeTo: parent) == CGRect(x: 420, y: 150, width: 80, height: 40)
        )
        configuration.edge = .left
        configuration.alignment = .start
        #expect(
            configuration.frame(relativeTo: parent) == CGRect(x: 10, y: 460, width: 80, height: 40)
        )
        configuration.edge = .right
        configuration.alignment = .end
        configuration.offset = CGSize(width: 5, height: -5)
        #expect(
            configuration.frame(relativeTo: parent) == CGRect(x: 515, y: 195, width: 80, height: 40)
        )
        configuration.size = .parentHeight(width: 50)
        #expect(configuration.frame(relativeTo: parent).size == CGSize(width: 50, height: 300))
        configuration.size = .parentWidth(height: 60)
        #expect(configuration.frame(relativeTo: parent).size == CGSize(width: 400, height: 60))
    }

    // MARK: - Content Width
    @Test func contentWidthTracksContentAndCapsAtParent() async throws {
        let controller = AlwaysOnTopWindowController()
        let id = ChildWindowID("dynamic")
        let model = ChildWidthModel()
        var configuration = AlwaysOnTopWindowConfiguration(
            size: CGSize(width: 500, height: 250),
            minSize: CGSize(width: 100, height: 100),
            maintainsContentAspectRatio: false
        )
        controller.show(configuration: configuration) { Color.clear }
        defer { controller.hide() }
        controller.showChild(
            id,
            configuration: .init(
                alignment: .start,
                size: .content,
                style: .init(contentInsets: EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
            )
        ) {
            ChildWidthTestView(model: model)
        }
        try await waitForWidth(90, controller: controller, id: id)
        #expect(controller.childFrame(id)?.height == 20)
        model.width = 800
        try await waitForWidth(500, controller: controller, id: id)
        configuration.size.width = 300
        controller.updateGeometry(configuration: configuration)
        #expect(controller.childFrame(id)?.width == 300)
        model.width = 40
        try await waitForWidth(50, controller: controller, id: id)
    }

    // MARK: - Sentence Presentation Responsiveness
    @Test func sentenceButtonsKeepMainActorResponsive() async throws {
        let floating = FloatingWindowController.shared
        let previous = floating.sentenceService
        let service = SentenceCompletionService(
            minimumInterval: .zero,
            context: { predictionContext("I want") },
            selection: { AIProviderSelection(provider: .apple) },
            generate: { _ in
                try await Task.sleep(for: .milliseconds(80))
                return
                    #"["I want to visit the museum tomorrow.","I want to finish my project today."]"#
            },
            insert: { _, _ in true }
        )
        floating.sentenceService = service
        let controller = AlwaysOnTopWindowController()
        controller.show(configuration: .init(size: CGSize(width: 600, height: 250))) { Color.clear }
        defer {
            controller.hide()
            service.stop()
            floating.sentenceService = previous
        }
        for _ in 0..<8 {
            service.start()
            await eventually { service.isGenerating }
            controller.showChild(.keyboardCompanion, configuration: .keyboardCompanion) {
                KeyboardCompanionView()
            }
            await eventually { !service.suggestions.isEmpty }
            controller.showChild(.keyboardCompanion, configuration: .keyboardCompanion) {
                KeyboardCompanionView()
            }
            try await Task.sleep(for: .milliseconds(300))
            service.stop()
        }
        controller.showChild(.keyboardCompanion, configuration: .keyboardCompanion) {
            KeyboardCompanionView()
        }
        #expect(controller.isChildVisible(.keyboardCompanion))
        #expect(controller.childFrame(.keyboardCompanion)?.width == controller.frame?.width)
    }

    // MARK: - Empty Area Clickthrough
    @Test func emptyAreaPassesThroughWhileSuggestionRegionsRemainInteractive() {
        let panel = NSPanel(
            contentRect: CGRect(x: 100, y: 100, width: 600, height: 50),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        let content = NSView(frame: CGRect(x: 0, y: 0, width: 600, height: 50))
        let button = KeyMouseEventNSView(frame: CGRect(x: 40, y: 5, width: 120, height: 40))
        content.addSubview(button)
        panel.contentView = content
        let passthrough = WindowMousePassthrough(panel: panel, content: content)
        passthrough.update(at: panel.convertPoint(toScreen: NSPoint(x: 400, y: 25)))
        #expect(panel.ignoresMouseEvents)
        passthrough.update(at: panel.convertPoint(toScreen: NSPoint(x: 60, y: 25)))
        #expect(!panel.ignoresMouseEvents)
        button.isHidden = true
        passthrough.update(at: panel.convertPoint(toScreen: NSPoint(x: 60, y: 25)))
        #expect(panel.ignoresMouseEvents)
    }

    // MARK: - Layout Wait
    private func waitForWidth(
        _ width: CGFloat,
        controller: AlwaysOnTopWindowController,
        id: ChildWindowID
    ) async throws {
        for _ in 0..<20 {
            if controller.childFrame(id)?.width == width { break }
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(controller.childFrame(id)?.width == width)
    }

}

// MARK: - Dynamic Content Fixture
@Observable @MainActor
private final class ChildWidthModel {
    var width: CGFloat = 80
}

private struct ChildWidthTestView: View {
    let model: ChildWidthModel

    // MARK: - Body
    var body: some View {
        Color.clear.frame(width: model.width, height: 20)
    }
}
