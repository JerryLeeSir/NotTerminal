import Combine
import Foundation

struct GitChange: Identifiable, Equatable {
    let indexStatus: Character
    let workTreeStatus: Character
    let path: String

    var id: String { "\(indexStatus)\(workTreeStatus):\(path)" }
    var isStaged: Bool { indexStatus != " " && indexStatus != "?" }
    var isUnstaged: Bool { workTreeStatus != " " || indexStatus == "?" }

    var badge: String {
        let status = isStaged ? indexStatus : workTreeStatus
        return status == "?" ? "U" : String(status)
    }
}

enum GitReferenceKind: String, Equatable {
    case local
    case remote
    case tag
}

struct GitReference: Identifiable, Equatable {
    let fullName: String
    let shortName: String
    let kind: GitReferenceKind
    let upstreamShortName: String?
    let isCurrent: Bool

    var id: String { fullName }

    var displayName: String {
        guard kind == .remote, let separator = shortName.firstIndex(of: "/") else {
            return shortName
        }
        return String(shortName[shortName.index(after: separator)...])
    }

    /// The remote that owns this reference, or nil when it has none.
    ///
    /// Only remote-tracking refs carry a remote in their name. A local branch
    /// can be configured to track another *local* branch, and falling back to
    /// the first path component of that upstream would name a repository that
    /// does not exist.
    var remoteName: String? {
        guard kind == .remote, let separator = shortName.firstIndex(of: "/") else {
            return nil
        }
        return String(shortName[..<separator])
    }
}

struct GitStatusSnapshot: Equatable {
    let branch: String
    let upstream: String?
    let ahead: Int
    let behind: Int
    let changes: [GitChange]
}

struct GitComparison: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let patch: String
}

struct GitCommandResult: Sendable {
    let output: String
    let error: String
    let status: Int32

    var message: String {
        let error = error.trimmingCharacters(in: .whitespacesAndNewlines)
        if !error.isEmpty { return error }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum GitService {
    static func run(directory: URL, arguments: [String]) -> GitCommandResult {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        // `core.quotepath=false` keeps non-ASCII paths readable in the diff
        // sheet. Status output is read with `-z`, which is what actually
        // guarantees unquoted paths, so this option is not load-bearing there.
        process.arguments = ["-C", directory.path, "-c", "core.quotepath=false"] + arguments
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            return GitCommandResult(output: "", error: error.localizedDescription, status: -1)
        }

        // Both pipes must be drained concurrently. Reading stdout to EOF
        // first deadlocks as soon as git fills the stderr pipe buffer while
        // stdout is still open: git blocks writing stderr, this side blocks
        // reading stdout, and neither ever finishes — leaving `isBusy` stuck
        // true and the whole dropdown disabled.
        let errorBox = DataBox()
        let errorHandle = stderr.fileHandleForReading
        let drained = DispatchGroup()
        drained.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            errorBox.store(errorHandle.readDataToEndOfFile())
            drained.leave()
        }
        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        drained.wait()
        process.waitUntilExit()

        return GitCommandResult(
            output: String(decoding: outputData, as: UTF8.self),
            error: String(decoding: errorBox.value, as: UTF8.self),
            status: process.terminationStatus
        )
    }

    private final class DataBox: @unchecked Sendable {
        private let lock = NSLock()
        private var stored = Data()

        func store(_ data: Data) {
            lock.lock()
            stored = data
            lock.unlock()
        }

        var value: Data {
            lock.lock()
            defer { lock.unlock() }
            return stored
        }
    }

    /// Parses `git status --porcelain=v1 -z --branch`.
    ///
    /// `-z` is required rather than the newline form: without it git quotes
    /// every path containing a space or a non-ASCII byte using C escapes, and
    /// that quoted text is handed straight back to `git add -- <path>`, which
    /// fails with "pathspec did not match any files". With `-z`, paths are
    /// emitted verbatim, records are NUL-separated, and a rename/copy record
    /// lists the destination first with the original path as the *following*
    /// NUL-separated field.
    static func parseStatus(_ output: String) -> GitStatusSnapshot {
        var branch = ""
        var upstream: String?
        var ahead = 0
        var behind = 0
        var changes: [GitChange] = []

        let records = output.split(separator: "\0", omittingEmptySubsequences: true)
        var index = 0
        while index < records.count {
            let record = records[index]
            index += 1

            if record.hasPrefix("## ") {
                let parsed = parseBranchHeader(String(record.dropFirst(3)))
                branch = parsed.branch
                upstream = parsed.upstream
                ahead = parsed.ahead
                behind = parsed.behind
                continue
            }
            guard record.count >= 4 else { continue }
            let characters = Array(record)
            let indexStatus = characters[0]
            let workTreeStatus = characters[1]

            // Skip the paired "original path" field of a rename or copy.
            if indexStatus == "R" || indexStatus == "C", index < records.count {
                index += 1
            }
            changes.append(
                GitChange(
                    indexStatus: indexStatus,
                    workTreeStatus: workTreeStatus,
                    path: String(characters.dropFirst(3))
                )
            )
        }
        return GitStatusSnapshot(
            branch: branch,
            upstream: upstream,
            ahead: ahead,
            behind: behind,
            changes: changes
        )
    }

    private static func parseBranchHeader(
        _ description: String
    ) -> (branch: String, upstream: String?, ahead: Int, behind: Int) {
        // A detached HEAD reports `## HEAD (no branch)`. Passing "HEAD" off as
        // a branch name would leave the repository with no current reference:
        // every branch-relative action is disabled and no row can be marked
        // current.
        if description.hasPrefix("HEAD (no branch)") {
            return (branch: "", upstream: nil, ahead: 0, behind: 0)
        }
        for prefix in ["No commits yet on ", "Initial commit on "]
            where description.hasPrefix(prefix) {
            return (branch: String(description.dropFirst(prefix.count)), upstream: nil, ahead: 0, behind: 0)
        }
        let tracking = description.components(separatedBy: "...")
        let branch = tracking[0].components(separatedBy: " ").first ?? ""
        guard tracking.count > 1 else {
            return (branch: branch, upstream: nil, ahead: 0, behind: 0)
        }
        let upstreamDescription = tracking[1]
        let upstream = upstreamDescription.components(separatedBy: " ").first
        return (
            branch: branch,
            upstream: (upstream?.isEmpty == false) ? upstream : nil,
            ahead: trackingCount(named: "ahead", in: upstreamDescription),
            behind: trackingCount(named: "behind", in: upstreamDescription)
        )
    }

    /// Parses `for-each-ref` output formatted as
    /// `refname \t shortname \t upstream \t HEAD`.
    ///
    /// The checked-out branch is read from the trailing `%(HEAD)` field, which
    /// git prints as `*`, rather than by comparing against a branch name
    /// captured by an earlier `git status`. The dropdown refreshes refs when it
    /// opens without re-running status, so an external `git switch` run in the
    /// embedded terminal would otherwise leave the previous branch marked as
    /// current — and the newly checked-out one missing from the list entirely.
    static func parseReferences(_ output: String) -> [GitReference] {
        output.split(separator: "\n", omittingEmptySubsequences: true).compactMap { rawLine in
            let fields = rawLine.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard fields.count >= 2 else { return nil }
            let fullName = fields[0]
            let shortName = fields[1]
            let kind: GitReferenceKind
            if fullName.hasPrefix("refs/heads/") {
                kind = .local
            } else if fullName.hasPrefix("refs/remotes/") {
                guard !fullName.hasSuffix("/HEAD") else { return nil }
                kind = .remote
            } else if fullName.hasPrefix("refs/tags/") {
                kind = .tag
            } else {
                return nil
            }
            let upstream = fields.count > 2 && !fields[2].isEmpty ? fields[2] : nil
            let isCurrent = kind == .local && fields.count > 3 && fields[3] == "*"
            return GitReference(
                fullName: fullName,
                shortName: shortName,
                kind: kind,
                upstreamShortName: upstream,
                isCurrent: isCurrent
            )
        }
        .sorted { lhs, rhs in
            if lhs.isCurrent != rhs.isCurrent { return lhs.isCurrent }
            if lhs.kind != rhs.kind { return referenceOrder(lhs.kind) < referenceOrder(rhs.kind) }
            return lhs.shortName.localizedStandardCompare(rhs.shortName) == .orderedAscending
        }
    }

    static func parseBranches(_ output: String) -> (local: [String], remote: [String]) {
        var local: [String] = []
        var remote: [String] = []
        for line in output.split(separator: "\n", omittingEmptySubsequences: true).map(String.init) {
            if line.hasPrefix("refs/heads/") {
                local.append(String(line.dropFirst("refs/heads/".count)))
            } else if line.hasPrefix("refs/remotes/") {
                let name = String(line.dropFirst("refs/remotes/".count))
                if name.hasSuffix("/HEAD") { continue }
                remote.append(name)
            }
        }
        return (local.sorted(), remote.sorted())
    }

    private static func trackingCount(named name: String, in description: String) -> Int {
        guard let range = description.range(of: "\(name) ") else { return 0 }
        let suffix = description[range.upperBound...]
        let digits = suffix.prefix { $0.isNumber }
        return Int(digits) ?? 0
    }

    private static func referenceOrder(_ kind: GitReferenceKind) -> Int {
        switch kind {
        case .local: return 0
        case .remote: return 1
        case .tag: return 2
        }
    }
}

@MainActor
final class GitRepository: ObservableObject {
    let directory: URL
    @Published private(set) var isRepository = false
    @Published private(set) var branch = ""
    @Published private(set) var upstream: String?
    @Published private(set) var ahead = 0
    @Published private(set) var behind = 0
    @Published private(set) var changes: [GitChange] = []
    @Published private(set) var references: [GitReference] = []
    @Published private(set) var recentReferenceIDs: [String] = []
    @Published private(set) var isBusy = false
    @Published private(set) var message: String?
    @Published private(set) var comparison: GitComparison?

    private var recentDefaultsKey: String { "recentGitReferences:\(directory.path)" }

    init(directory: URL) {
        self.directory = directory
        self.recentReferenceIDs = UserDefaults.standard.stringArray(
            forKey: "recentGitReferences:\(directory.path)"
        ) ?? []
    }

    var localReferences: [GitReference] { references.filter { $0.kind == .local } }
    var remoteReferences: [GitReference] { references.filter { $0.kind == .remote } }
    var tagReferences: [GitReference] { references.filter { $0.kind == .tag } }
    var currentReference: GitReference? { localReferences.first(where: \.isCurrent) }
    var recentReferences: [GitReference] {
        recentReferenceIDs.compactMap { id in references.first { $0.id == id } }
    }

    func refresh(
        preservingMessage: Bool = false,
        completion: (() -> Void)? = nil
    ) {
        let preservedMessage = preservingMessage ? message : nil
        run(["status", "--porcelain=v1", "-z", "--branch"]) { [weak self] result in
            guard let self else { return }
            self.isRepository = result.status == 0
            if result.status == 0 {
                let status = GitService.parseStatus(result.output)
                self.branch = status.branch
                self.upstream = status.upstream
                self.ahead = status.ahead
                self.behind = status.behind
                self.changes = status.changes
                self.message = preservedMessage
                self.refreshBranches(completion: completion)
                self.clearRecentReferencesIfUnavailable()
            } else {
                self.branch = ""
                self.upstream = nil
                self.ahead = 0
                self.behind = 0
                self.changes = []
                self.references = []
                self.message = "The current directory is not a Git repository."
                completion?()
            }
        }
    }

    func refreshBranches(completion: (() -> Void)? = nil) {
        run([
            "for-each-ref",
            "--format=%(refname)%09%(refname:short)%09%(upstream:short)%09%(HEAD)",
            "refs/heads",
            "refs/remotes",
            "refs/tags",
        ]) { [weak self] result in
            guard let self else { return }
            guard result.status == 0 else {
                self.references = []
                self.message = result.message
                completion?()
                return
            }
            self.references = GitService.parseReferences(result.output)
            completion?()
        }
    }

    func fetch(completion: ((Bool) -> Void)? = nil) {
        perform(["fetch", "--all", "--prune"], completion: completion)
    }

    func updateCurrentBranch(completion: ((Bool) -> Void)? = nil) {
        perform(["pull", "--ff-only"], completion: completion)
    }

    func push(_ reference: GitReference, completion: ((Bool) -> Void)? = nil) {
        guard reference.kind == .local else { return }
        // Only a *remote-tracking* upstream lets a bare `git push` resolve the
        // destination itself. A local branch configured to track another local
        // branch satisfies `upstreamShortName != nil` but has no remote behind
        // it, so the shortcut would run `git push` against nothing.
        if reference.isCurrent,
           let upstream = reference.upstreamShortName,
           references.contains(where: { $0.kind == .remote && $0.shortName == upstream }) {
            perform(["push"], completion: completion)
            return
        }
        // `--set-upstream` resolves its remote by name, so it has to be a
        // remote that exists. Take it from the branch's upstream when that
        // upstream is remote-tracking; a branch tracking another *local* branch
        // has no remote in its configuration to read, so fall back to the
        // conventional default rather than inventing one from the upstream name.
        let remote = reference.upstreamShortName
            .flatMap { upstream in
                references.first { $0.kind == .remote && $0.shortName == upstream }?.remoteName
            }
            ?? "origin"
        perform(["push", "--set-upstream", remote, reference.shortName], completion: completion)
    }

    func checkout(_ reference: GitReference, completion: ((Bool) -> Void)? = nil) {
        let arguments: [String]
        switch reference.kind {
        case .local:
            arguments = ["switch", reference.shortName]
        case .remote:
            arguments = ["switch", "--track", reference.shortName]
        case .tag:
            arguments = ["switch", "--detach", reference.shortName]
        }
        perform(arguments) { [weak self] succeeded in
            if succeeded { self?.recordRecentReference(reference) }
            completion?(succeeded)
        }
    }

    func checkoutRevision(_ revision: String, completion: ((Bool) -> Void)? = nil) {
        perform(["switch", "--detach", revision], completion: completion)
    }

    func createBranch(
        named rawName: String,
        from reference: GitReference,
        checkout: Bool,
        completion: ((Bool) -> Void)? = nil
    ) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            message = "Enter a branch name."
            completion?(false)
            return
        }
        let arguments = checkout
            ? ["switch", "-c", name, reference.shortName]
            : ["branch", name, reference.shortName]
        perform(arguments, completion: completion)
    }

    func deleteBranch(_ reference: GitReference, completion: ((Bool) -> Void)? = nil) {
        guard reference.kind == .local, !reference.isCurrent else {
            message = "The current branch cannot be deleted."
            completion?(false)
            return
        }
        perform(["branch", "-d", "--", reference.shortName], completion: completion)
    }

    func compareWithWorkingTree(
        _ reference: GitReference,
        completion: ((Bool) -> Void)? = nil
    ) {
        compare(
            title: "\(reference.shortName) vs Working Tree",
            arguments: ["diff", "--no-ext-diff", "--no-color", reference.shortName, "--"],
            completion: completion
        )
    }

    func compare(
        _ source: GitReference,
        with target: GitReference,
        completion: ((Bool) -> Void)? = nil
    ) {
        compare(
            title: "\(source.shortName) vs \(target.shortName)",
            arguments: [
                "diff", "--no-ext-diff", "--no-color",
                "\(source.shortName)...\(target.shortName)", "--",
            ],
            completion: completion
        )
    }

    func dismissComparison() { comparison = nil }
    func clearMessage() { message = nil }

    func stage(_ change: GitChange) { perform(["add", "--", change.path]) }
    func unstage(_ change: GitChange) { perform(["reset", "HEAD", "--", change.path]) }
    func stageAll() { perform(["add", "-A"]) }
    func unstageAll() { perform(["reset", "HEAD"]) }

    func commit(message commitMessage: String, completion: @escaping (Bool) -> Void) {
        perform(["commit", "-m", commitMessage], completion: completion)
    }

    private func compare(
        title: String,
        arguments: [String],
        completion: ((Bool) -> Void)?
    ) {
        run(arguments) { [weak self] result in
            guard let self else { return }
            if result.status == 0 {
                self.comparison = GitComparison(
                    title: title,
                    patch: result.output.isEmpty ? "No differences." : result.output
                )
                self.message = nil
                completion?(true)
            } else {
                self.message = result.message
                completion?(false)
            }
        }
    }

    private func recordRecentReference(_ reference: GitReference) {
        recentReferenceIDs.removeAll { $0 == reference.id }
        recentReferenceIDs.insert(reference.id, at: 0)
        recentReferenceIDs = Array(recentReferenceIDs.prefix(6))
        UserDefaults.standard.set(recentReferenceIDs, forKey: recentDefaultsKey)
    }

    /// Recents are persisted per directory path, so a path that used to hold a
    /// repository can be reused by an unrelated project. Without this, ids
    /// from the old repository would resurface as dead "Recent" entries the
    /// moment a new repository appeared at the same location.
    private func clearRecentReferencesIfUnavailable() {
        let available = Set(references.map(\.id))
        let live = recentReferenceIDs.filter { available.contains($0) }
        guard live.count != recentReferenceIDs.count else { return }
        recentReferenceIDs = live
        UserDefaults.standard.set(live, forKey: recentDefaultsKey)
    }

    private func perform(_ arguments: [String], completion: ((Bool) -> Void)? = nil) {
        run(arguments) { [weak self] result in
            guard let self else { return }
            let succeeded = result.status == 0
            self.message = succeeded ? nil : result.message
            self.refresh(preservingMessage: !succeeded) {
                completion?(succeeded)
            }
        }
    }

    private func run(_ arguments: [String], completion: @escaping (GitCommandResult) -> Void) {
        isBusy = true
        let directory = directory
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                GitService.run(directory: directory, arguments: arguments)
            }.value
            isBusy = false
            completion(result)
        }
    }
}
