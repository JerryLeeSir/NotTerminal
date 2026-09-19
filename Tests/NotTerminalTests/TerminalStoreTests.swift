import Foundation
import XCTest
@testable import NotTerminal

@MainActor
final class TerminalStoreTests: XCTestCase {
    func testAddingTabTargetsSuppliedWorkspace() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NotTerminalTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = TerminalStore()
        store.createWorkspace(directory: directory)

        let workspace = try XCTUnwrap(store.selectedWorkspace)
        let originalTabCount = workspace.tabs.count
        let newTab = try XCTUnwrap(store.addTab(to: workspace))

        XCTAssertEqual(workspace.tabs.count, originalTabCount + 1)
        XCTAssertEqual(workspace.selectedTabID, newTab.id)
        XCTAssertEqual(newTab.workingDirectory, directory.path)
    }
}
