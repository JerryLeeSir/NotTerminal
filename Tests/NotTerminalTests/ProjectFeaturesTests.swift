import Foundation
import XCTest
@testable import NotTerminal

@MainActor
final class ProjectFeaturesTests: XCTestCase {
    func testProjectMonogramUsesWordAndCamelCaseInitials() {
        XCTAssertEqual(ProjectMonogram.make(from: "JiajunTV"), "JT")
        XCTAssertEqual(ProjectMonogram.make(from: "NotTerminal"), "NT")
        XCTAssertEqual(ProjectMonogram.make(from: "my-project"), "MP")
        XCTAssertEqual(ProjectMonogram.make(from: "XMLParser"), "XP")
    }

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
            "## feature/editor...origin/feature/editor [ahead 2, behind 1]\nM  staged.swift\n M changed.swift\n?? new.swift\n"
        )

        XCTAssertEqual(parsed.branch, "feature/editor")
        XCTAssertEqual(parsed.upstream, "origin/feature/editor")
        XCTAssertEqual(parsed.ahead, 2)
        XCTAssertEqual(parsed.behind, 1)
        XCTAssertEqual(parsed.changes.count, 3)
        XCTAssertTrue(parsed.changes[0].isStaged)
        XCTAssertFalse(parsed.changes[0].isUnstaged)
        XCTAssertFalse(parsed.changes[1].isStaged)
        XCTAssertTrue(parsed.changes[1].isUnstaged)
        XCTAssertEqual(parsed.changes[2].badge, "U")
    }

    func testGitBranchParserSplitsLocalAndRemoteAndSkipsHead() {
        let parsed = GitService.parseBranches(
            "refs/heads/main\nrefs/heads/feature/editor\nrefs/remotes/origin/HEAD\nrefs/remotes/origin/main\n"
        )

        XCTAssertEqual(parsed.local, ["feature/editor", "main"])
        XCTAssertEqual(parsed.remote, ["origin/main"])
    }

    func testGitReferenceParserIncludesUpstreamTagsAndCurrentBranch() {
        let parsed = GitService.parseReferences(
            "refs/heads/main\tmain\torigin/main\n"
                + "refs/heads/feature/editor\tfeature/editor\t\n"
                + "refs/remotes/origin/HEAD\torigin/HEAD\t\n"
                + "refs/remotes/origin/main\torigin/main\t\n"
                + "refs/tags/v0.1\tv0.1\t\n",
            currentBranch: "main"
        )

        XCTAssertEqual(parsed.count, 4)
        XCTAssertTrue(parsed.first?.isCurrent == true)
        XCTAssertEqual(parsed.first?.upstreamShortName, "origin/main")
        XCTAssertEqual(parsed.filter { $0.kind == .remote }.map(\.shortName), ["origin/main"])
        XCTAssertEqual(parsed.filter { $0.kind == .tag }.map(\.shortName), ["v0.1"])
    }

    func testGitRepositoryCreatesChecksOutAndDeletesBranch() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        XCTAssertEqual(GitService.run(directory: directory, arguments: ["init", "--quiet", "-b", "main"]).status, 0)
        try "initial\n".write(
            to: directory.appendingPathComponent("README.md"),
            atomically: true,
            encoding: .utf8
        )
        XCTAssertEqual(GitService.run(directory: directory, arguments: ["add", "README.md"]).status, 0)
        XCTAssertEqual(
            GitService.run(
                directory: directory,
                arguments: [
                    "-c", "user.name=NotTerminal Tests",
                    "-c", "user.email=tests@example.invalid",
                    "commit", "--quiet", "-m", "Initial",
                ]
            ).status,
            0
        )

        let repository = GitRepository(directory: directory)
        let main = GitReference(
            fullName: "refs/heads/main",
            shortName: "main",
            kind: .local,
            upstreamShortName: nil,
            isCurrent: true
        )
        let created = await perform { completion in
            repository.createBranch(
                named: "feature/dropdown",
                from: main,
                checkout: true,
                completion: completion
            )
        }
        XCTAssertTrue(created)
        XCTAssertEqual(currentBranch(in: directory), "feature/dropdown")
        XCTAssertTrue(repository.references.contains { $0.shortName == "feature/dropdown" })

        let checkedOut = await perform { completion in
            repository.checkout(main, completion: completion)
        }
        XCTAssertTrue(checkedOut)
        XCTAssertEqual(currentBranch(in: directory), "main")

        let feature = GitReference(
            fullName: "refs/heads/feature/dropdown",
            shortName: "feature/dropdown",
            kind: .local,
            upstreamShortName: nil,
            isCurrent: false
        )
        let deleted = await perform { completion in
            repository.deleteBranch(feature, completion: completion)
        }
        XCTAssertTrue(deleted)
        XCTAssertNotEqual(
            GitService.run(directory: directory, arguments: ["show-ref", "--verify", feature.fullName]).status,
            0
        )
        XCTAssertFalse(repository.references.contains { $0.shortName == "feature/dropdown" })
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

    private func perform(
        _ operation: (@escaping (Bool) -> Void) -> Void
    ) async -> Bool {
        await withCheckedContinuation { continuation in
            operation { continuation.resume(returning: $0) }
        }
    }

    private func currentBranch(in directory: URL) -> String {
        GitService.run(
            directory: directory,
            arguments: ["branch", "--show-current"]
        ).output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
