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
            "## feature/editor...origin/feature/editor [ahead 2, behind 1]\0M  staged.swift\0 M changed.swift\0?? new.swift\0"
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

    func testGitStatusParserKeepsPathsWithSpacesVerbatim() {
        // `-z` output is unquoted. The newline form would render these as
        // "my report.txt" with literal quotes, and that quoted string was being
        // passed back to `git add --`, which rejects it as a pathspec.
        let parsed = GitService.parseStatus(
            "## main\0?? my report.txt\0 M spaced name.swift\0"
        )

        XCTAssertEqual(parsed.changes.map(\.path), ["my report.txt", "spaced name.swift"])
        XCTAssertFalse(parsed.changes.contains { $0.path.contains("\"") })
    }

    func testGitStatusParserUsesRenameDestinationAndSkipsItsSourceField() {
        // A rename record is the status pair + destination, then the original
        // path as a separate NUL-separated field.
        let parsed = GitService.parseStatus("## main\0R  renamed file.txt\0old file.txt\0?? plain.txt\0")

        XCTAssertEqual(parsed.changes.count, 2)
        XCTAssertEqual(parsed.changes[0].path, "renamed file.txt")
        XCTAssertEqual(parsed.changes[0].badge, "R")
        XCTAssertEqual(parsed.changes[1].path, "plain.txt")
    }

    func testGitStatusParserTreatsDetachedHeadAsNoBranch() {
        // Reporting "HEAD" as a branch name leaves the repository with no
        // current reference, disabling every branch-relative action.
        let parsed = GitService.parseStatus("## HEAD (no branch)\0")

        XCTAssertEqual(parsed.branch, "")
        XCTAssertNil(parsed.upstream)
        XCTAssertEqual(parsed.ahead, 0)
        XCTAssertEqual(parsed.behind, 0)
        XCTAssertTrue(parsed.changes.isEmpty)
    }

    func testGitStatusParserReportsBehindAndDivergence() {
        let behind = GitService.parseStatus("## main...origin/main [behind 1]\0")
        XCTAssertEqual(behind.behind, 1)
        XCTAssertEqual(behind.ahead, 0)
        XCTAssertEqual(behind.upstream, "origin/main")

        let diverged = GitService.parseStatus("## main...origin/main [ahead 1, behind 1]\0")
        XCTAssertEqual(diverged.ahead, 1)
        XCTAssertEqual(diverged.behind, 1)
        XCTAssertEqual(diverged.upstream, "origin/main")
    }

    func testGitStatusParserHandlesRepositoryWithoutCommits() {
        let parsed = GitService.parseStatus("## No commits yet on main\0?? first.txt\0")

        XCTAssertEqual(parsed.branch, "main")
        XCTAssertNil(parsed.upstream)
        XCTAssertEqual(parsed.changes.map(\.path), ["first.txt"])
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
            "refs/heads/main\tmain\torigin/main\t*\n"
                + "refs/heads/feature/editor\tfeature/editor\t\t \n"
                + "refs/remotes/origin/HEAD\torigin/HEAD\t\t\n"
                + "refs/remotes/origin/main\torigin/main\t\t\n"
                + "refs/tags/v0.1\tv0.1\t\t\n"
        )

        XCTAssertEqual(parsed.count, 4)
        XCTAssertTrue(parsed.first?.isCurrent == true)
        XCTAssertEqual(parsed.first?.upstreamShortName, "origin/main")
        XCTAssertEqual(parsed.filter { $0.kind == .remote }.map(\.shortName), ["origin/main"])
        XCTAssertEqual(parsed.filter { $0.kind == .tag }.map(\.shortName), ["v0.1"])
    }

    func testGitReferenceParserTrustsHeadMarkerOverCachedBranchName() {
        // What git reports wins: an external `git switch` must not leave the
        // previous branch marked current, nor hide the new one.
        let parsed = GitService.parseReferences(
            "refs/heads/main\tmain\t\t \n"
                + "refs/heads/feature\tfeature\t\t*\n"
        )

        XCTAssertEqual(parsed.filter(\.isCurrent).map(\.shortName), ["feature"])
    }

    func testBranchActionListOffersCheckoutAndGuardsTheCurrentBranch() {
        let current = GitReference(
            fullName: "refs/heads/main", shortName: "main",
            kind: .local, upstreamShortName: "origin/main", isCurrent: true
        )
        let other = GitReference(
            fullName: "refs/heads/feature/music", shortName: "feature/music",
            kind: .local, upstreamShortName: nil, isCurrent: false
        )
        let tag = GitReference(
            fullName: "refs/tags/v2.2.1", shortName: "v2.2.1",
            kind: .tag, upstreamShortName: nil, isCurrent: false
        )

        // Checkout must always be offered, disabled only where it is a no-op or
        // impossible — it is the whole point of the menu.
        let forOther = BranchActions.list(for: other, current: current)
        let checkout = forOther.first { $0.id == "checkout" }
        XCTAssertNotNil(checkout, "a non-current branch must offer Checkout")
        XCTAssertEqual(checkout?.isEnabled, true)
        XCTAssertEqual(checkout?.title, "Checkout 'feature/music'")

        let forCurrent = BranchActions.list(for: current, current: current)
        XCTAssertEqual(forCurrent.first { $0.id == "checkout" }?.isEnabled, false)
        // Update pulls the checked-out branch, so only that row offers it.
        XCTAssertNotNil(forCurrent.first { $0.id == "update" })
        XCTAssertNil(forOther.first { $0.id == "update" })
        // Delete is local-only and never offered for the checked-out branch.
        XCTAssertNotNil(forOther.first { $0.id == "delete" })
        XCTAssertNil(forCurrent.first { $0.id == "delete" })
        XCTAssertNil(BranchActions.list(for: tag, current: current).first { $0.id == "delete" })

        // Push is local-only (GitRepository.push guards on `kind == .local`),
        // while the read-only actions apply to every kind.
        for reference in [current, other, tag] {
            let ids = BranchActions.list(for: reference, current: current).map(\.id)
            XCTAssertTrue(ids.contains("newBranch"), "\(reference.shortName) should offer new branch")
            XCTAssertTrue(ids.contains("diffWorkingTree"))
        }
        XCTAssertNil(BranchActions.list(for: tag, current: current).first { $0.id == "push" })
        XCTAssertNotNil(BranchActions.list(for: other, current: current).first { $0.id == "push" })

        // Detached HEAD: nothing is current, so Checkout stays available.
        let detached = BranchActions.list(for: other, current: nil)
        XCTAssertEqual(detached.first { $0.id == "checkout" }?.isEnabled, false)
    }

    func testRemoteNameIsOnlyDerivedFromRemoteTrackingRefs() {
        let local = GitReference(
            fullName: "refs/heads/topic",
            shortName: "topic",
            kind: .local,
            upstreamShortName: "main",
            isCurrent: false
        )
        XCTAssertNil(local.remoteName)

        let remote = GitReference(
            fullName: "refs/remotes/origin/topic",
            shortName: "origin/topic",
            kind: .remote,
            upstreamShortName: nil,
            isCurrent: false
        )
        XCTAssertEqual(remote.remoteName, "origin")
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
            arguments: ["status", "--porcelain=v1", "-z", "--branch"]
        )
        let status = GitService.parseStatus(result.output)

        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(status.changes.first?.path, "note.txt")
        XCTAssertEqual(status.changes.first?.badge, "U")
    }

    func testGitRepositoryTracksDetachedHeadAndExternalBranchSwitches() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try initializeRepository(at: directory, branch: "main")
        _ = GitService.run(directory: directory, arguments: ["branch", "other"])

        let repository = GitRepository(directory: directory)
        await refresh(repository)
        XCTAssertEqual(repository.branch, "main")
        XCTAssertEqual(repository.currentReference?.shortName, "main")

        // Switch outside the app, the way the embedded terminal would, then
        // refresh only the refs — the path taken when the dropdown opens.
        _ = GitService.run(directory: directory, arguments: ["switch", "--quiet", "other"])
        await refreshBranches(repository)

        XCTAssertEqual(repository.currentReference?.shortName, "other")
        XCTAssertEqual(repository.localReferences.filter(\.isCurrent).map(\.shortName), ["other"])
        XCTAssertTrue(repository.references.contains { $0.shortName == "other" })

        // A detached HEAD has no current branch at all, but must not claim
        // "HEAD" is one, and every ref has to remain listed.
        _ = GitService.run(directory: directory, arguments: ["switch", "--quiet", "--detach", "HEAD"])
        await refresh(repository)

        XCTAssertEqual(repository.branch, "")
        XCTAssertNil(repository.currentReference)
        XCTAssertFalse(repository.localReferences.contains { $0.isCurrent })
        XCTAssertTrue(repository.references.contains { $0.shortName == "other" })
    }

    func testGitRepositoryStagesFilesWhosePathsNeedQuoting() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try initializeRepository(at: directory, branch: "main")

        let fileName = "my report.txt"
        try "draft\n".write(
            to: directory.appendingPathComponent(fileName),
            atomically: true,
            encoding: .utf8
        )

        let repository = GitRepository(directory: directory)
        await refresh(repository)

        guard let change = repository.changes.first(where: { $0.path == fileName }) else {
            return XCTFail("expected an unquoted change for \(fileName), got \(repository.changes.map(\.path))")
        }
        repository.stage(change)

        await waitUntil { !repository.isBusy && repository.changes.allSatisfy(\.isStaged) }
        XCTAssertTrue(
            repository.changes.allSatisfy(\.isStaged),
            "`git add -- \(change.path)` should have staged the file, changes: \(repository.changes.map(\.path))"
        )
    }

    func testGitRepositoryRefreshesRefsWithoutRerunningStatus() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try initializeRepository(at: directory, branch: "main")

        let repository = GitRepository(directory: directory)
        await refresh(repository)
        XCTAssertEqual(repository.references.filter(\.isCurrent).map(\.shortName), ["main"])

        _ = GitService.run(directory: directory, arguments: ["switch", "--quiet", "-c", "solo"])
        await refreshBranches(repository)

        // Refreshing refs alone must pick up a branch created behind the app's
        // back — `branch` is intentionally left stale here.
        XCTAssertEqual(repository.currentReference?.shortName, "solo")
        XCTAssertTrue(repository.references.contains { $0.shortName == "solo" })
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

    private func refresh(_ repository: GitRepository) async {
        await withCheckedContinuation { continuation in
            repository.refresh { continuation.resume() }
        }
    }

    private func refreshBranches(_ repository: GitRepository) async {
        await withCheckedContinuation { continuation in
            repository.refreshBranches { continuation.resume() }
        }
    }

    /// `stage` and friends report through `@Published` state rather than a
    /// completion handler, so poll until the repository settles.
    private func waitUntil(
        timeout: TimeInterval = 5,
        _ condition: () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    private func initializeRepository(at directory: URL, branch: String) throws {
        XCTAssertEqual(
            GitService.run(directory: directory, arguments: ["init", "--quiet", "-b", branch]).status,
            0
        )
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
    }

    private func currentBranch(in directory: URL) -> String {
        GitService.run(
            directory: directory,
            arguments: ["branch", "--show-current"]
        ).output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
