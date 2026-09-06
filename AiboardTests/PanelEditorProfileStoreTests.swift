import Foundation
import Testing

@testable import Aiboard

// MARK: - PanelEditorProfileStoreTests
@MainActor
struct PanelEditorProfileStoreTests {
    // MARK: - Loading
    @Test func malformedPackageDoesNotHideValidProfiles() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeProfile(in: directory)
        try FileManager.default.createDirectory(
            at: directory.appending(path: "Broken.ascconfig"),
            withIntermediateDirectories: true
        )

        let store = PanelEditorProfileStore(profilesDirectoryURL: directory)

        #expect(store.panels.map(\.name) == ["Fixture Panel"])
        #expect(store.errorDescription?.contains("Broken.ascconfig") == true)
    }

    @Test func failedReloadKeepsLastWorkingKeyboardAndRecovers() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let definitionsURL = try writeProfile(in: directory)
        let store = PanelEditorProfileStore(profilesDirectoryURL: directory)
        let originalPanels = store.panels
        try Data("Invalid property list".utf8).write(to: definitionsURL)

        store.reload()

        #expect(store.panels == originalPanels)
        #expect(store.errorDescription != nil)

        try writeProfile(in: directory, panelName: "Updated Panel")
        store.reload()

        #expect(store.panels.map(\.name) == ["Updated Panel"])
        #expect(store.errorDescription == nil)
    }

    @Test func removingAllProfilesClearsTheOldKeyboard() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeProfile(in: directory)
        let store = PanelEditorProfileStore(profilesDirectoryURL: directory)
        try FileManager.default.removeItem(at: directory.appending(path: "Fixture.ascconfig"))

        store.reload()

        #expect(store.panels.isEmpty)
        #expect(store.errorDescription?.contains("Create a keyboard panel") == true)
    }

    @Test func directoryReadFailureKeepsLastWorkingKeyboard() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeProfile(in: directory)
        let store = PanelEditorProfileStore(profilesDirectoryURL: directory)
        let originalPanels = store.panels
        try FileManager.default.removeItem(at: directory)

        store.reload()

        #expect(store.panels == originalPanels)
        #expect(store.errorDescription != nil)
    }

    // MARK: - Fixtures
    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "AiboardProfileTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @discardableResult
    private func writeProfile(in directory: URL, panelName: String = "Fixture Panel") throws -> URL
    {
        let contents = directory.appending(path: "Fixture.ascconfig/Contents")
        let resources = contents.appending(path: "Resources")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        let info = [
            "ASCConfigurationIdentifier": "FIXTURE", "ASCConfigurationDisplayName": "Fixture",
        ]
        let definitions: [String: Any] = [
            "Panels": [
                "PANEL": ["Name": panelName, "Rect": "{{0, 0}, {200, 100}}", "PanelObjects": []]
            ]
        ]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: contents.appending(path: "Info.plist"))
        let definitionsURL = resources.appending(path: "PanelDefinitions.plist")
        try PropertyListSerialization.data(fromPropertyList: definitions, format: .xml, options: 0)
            .write(to: definitionsURL)
        return definitionsURL
    }
}
