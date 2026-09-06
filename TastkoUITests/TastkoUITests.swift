import XCTest

final class TastkoUITests: XCTestCase {
    // MARK: - Fitted Keyboard Window
    @MainActor
    func testToolbarWindowFitsAfterTogglesAndResize() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-pointerAutoHideEnabled", "NO", "-experimentalLockScreenDisplay", "YES",
        ]
        app.launch()
        let toggle = app.buttons["function-toolbar-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        let panel = app.descendants(matching: .dialog).firstMatch
        XCTAssertTrue(panel.exists)
        let close = app.buttons["Close"]
        let initialFrame = panel.frame
        let initiallyShown = toggle.value as? String == "Shown"

        func assertTitlebarFits() {
            XCTAssertLessThan(abs(close.frame.minY - panel.frame.minY), 5)
            XCTAssertEqual(app.buttons.matching(identifier: "function-toolbar-toggle").count, 1)
        }

        for _ in 0..<3 {
            toggle.click()
            Thread.sleep(forTimeInterval: 0.35)
            assertTitlebarFits()
            toggle.click()
            Thread.sleep(forTimeInterval: 0.35)
            assertTitlebarFits()
            XCTAssertEqual(panel.frame.minX, initialFrame.minX, accuracy: 1)
            XCTAssertEqual(panel.frame.maxY, initialFrame.maxY, accuracy: 1)
            XCTAssertEqual(panel.frame.width, initialFrame.width, accuracy: 1)
            XCTAssertEqual(panel.frame.height, initialFrame.height, accuracy: 1)
        }

        for _ in 0..<2 {
            let before = panel.frame
            let corner = panel.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1))
                .withOffset(CGVector(dx: -4, dy: -4))
            corner.click(
                forDuration: 0.1,
                thenDragTo: corner.withOffset(CGVector(dx: 100, dy: 180))
            )
            Thread.sleep(forTimeInterval: 0.35)
            assertTitlebarFits()
            XCTAssertGreaterThan(panel.frame.width, before.width)
            XCTAssertEqual(
                panel.frame.height,
                73 + (before.height - 73) * panel.frame.width / before.width,
                accuracy: 2
            )
            let resizedCorner = panel.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1))
                .withOffset(CGVector(dx: -4, dy: -4))
            resizedCorner.click(
                forDuration: 0.1,
                thenDragTo: resizedCorner.withOffset(
                    CGVector(
                        dx: before.width - panel.frame.width,
                        dy: before.height - panel.frame.height
                    )
                )
            )
            Thread.sleep(forTimeInterval: 0.35)
            assertTitlebarFits()
            toggle.click()
            Thread.sleep(forTimeInterval: 0.35)
        }
        XCTAssertEqual(toggle.value as? String == "Shown", initiallyShown)
        let screenshot = XCTAttachment(screenshot: panel.screenshot())
        screenshot.name = "Fitted keyboard after toolbar toggles and manual resize"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()
    }

    @MainActor
    func testCollapseAndExpand() throws {
        let app = XCUIApplication()
        app.launch()

        let minimizeButton = app.buttons["Minimize"]
        XCTAssertTrue(minimizeButton.waitForExistence(timeout: 5))
        minimizeButton.click()

        let expandButton = app.buttons["Expand"]
        XCTAssertTrue(expandButton.waitForExistence(timeout: 5))
        expandButton.click()

        XCTAssertTrue(minimizeButton.waitForExistence(timeout: 5))
    }

    @MainActor
    func testModifierTogglesReliably() throws {
        let app = XCUIApplication()
        app.launch()

        let shiftKey = app.buttons.matching(identifier: "⇧").firstMatch
        XCTAssertTrue(shiftKey.waitForExistence(timeout: 5))
        XCTAssertFalse(shiftKey.isSelected)

        for clickIndex in 1...10 {
            shiftKey.click()
            XCTAssertEqual(
                shiftKey.isSelected,
                clickIndex.isMultiple(of: 2) == false,
                "Shift did not toggle on click \(clickIndex)"
            )
        }
    }
}
