import Foundation
import XCTest
@testable import NotTerminal

@MainActor
final class ProjectFeaturesTests: XCTestCase {
    func testBundledEditorFontCanBeRegistered() {
        BundledFontRegistry.registerFonts()
        XCTAssertEqual(
            BundledFontRegistry.editorFont(size: 13).fontName,
            "JetBrainsMono-Regular"
        )
    }

    func testEditorDocumentTracksChangesAndSaves() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("hello.swift")
        try "let value = 1\n".write(to: file, atomically: true, encoding: .utf8)

        let document = try EditorDocument(url: file, workspaceDirectory: directory)
        XCTAssertEqual(document.relativePath, "hello.swift")
        XCTAssertFalse(document.isDirty)

        document.text = "let value = 2\n"
        XCTAssertTrue(document.isDirty)
        document.save()

        XCTAssertFalse(document.isDirty)
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "let value = 2\n")
    }

    func testProjectTreeSortsDirectoriesBeforeFilesAndExcludesBuildFolders() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("Sources"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: directory.appendingPathComponent(".git"), withIntermediateDirectories: true)
        try "text".write(to: directory.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)

        let root = ProjectFileNode(url: directory, isDirectory: true)
        root.loadChildren()

        XCTAssertEqual(root.children?.map(\.name), ["Sources", "README.md"])
    }

    func testGitStatusParserSeparatesIndexAndWorkTreeChanges() {
        let parsed = GitService.parseStatus(
            "## feature/editor...origin/feature/editor\nM  staged.swift\n M changed.swift\n?? new.swift\n"
        )

        XCTAssertEqual(parsed.branch, "feature/editor")
        XCTAssertEqual(parsed.changes.count, 3)
        XCTAssertTrue(parsed.changes[0].isStaged)
        XCTAssertFalse(parsed.changes[0].isUnstaged)
        XCTAssertFalse(parsed.changes[1].isStaged)
        XCTAssertTrue(parsed.changes[1].isUnstaged)
        XCTAssertEqual(parsed.changes[2].badge, "U")
    }

    func testGitServiceReadsRealRepositoryStatus() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        XCTAssertEqual(GitService.run(directory: directory, arguments: ["init", "--quiet"]).status, 0)
        try "draft\n".write(
            to: directory.appendingPathComponent("note.txt"),
            atomically: true,
            encoding: .utf8
        )

        let result = GitService.run(
            directory: directory,
            arguments: ["status", "--porcelain=v1", "--branch"]
        )
        let status = GitService.parseStatus(result.output)

        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(status.changes.first?.path, "note.txt")
        XCTAssertEqual(status.changes.first?.badge, "U")
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("NotTerminalProjectTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
