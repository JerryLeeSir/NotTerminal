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

struct GitCommandResult: Sendable {
    let output: String
    let error: String
    let status: Int32
}

enum GitService {
    static func run(directory: URL, arguments: [String]) -> GitCommandResult {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", directory.path, "-c", "core.quotepath=false"] + arguments
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            return GitCommandResult(output: "", error: error.localizedDescription, status: -1)
        }

        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return GitCommandResult(
            output: String(decoding: outputData, as: UTF8.self),
            error: String(decoding: errorData, as: UTF8.self),
            status: process.terminationStatus
        )
    }

    static func parseStatus(_ output: String) -> (branch: String, changes: [GitChange]) {
        var branch = ""
        var changes: [GitChange] = []
        for line in output.split(separator: "\n", omittingEmptySubsequences: true).map(String.init) {
            if line.hasPrefix("## ") {
                let branchDescription = String(line.dropFirst(3))
                branch = branchDescription.components(separatedBy: "...").first?
                    .components(separatedBy: " ").first ?? ""
                continue
            }
            guard line.count >= 4 else { continue }
            let characters = Array(line)
            var path = String(characters.dropFirst(3))
            if let range = path.range(of: " -> ") { path = String(path[range.upperBound...]) }
            changes.append(
                GitChange(indexStatus: characters[0], workTreeStatus: characters[1], path: path)
            )
        }
        return (branch, changes)
    }
}

@MainActor
final class GitRepository: ObservableObject {
    let directory: URL
    @Published private(set) var isRepository = false
    @Published private(set) var branch = ""
    @Published private(set) var changes: [GitChange] = []
    @Published private(set) var isBusy = false
    @Published private(set) var message: String?

    init(directory: URL) {
        self.directory = directory
    }

    func refresh() {
        run(["status", "--porcelain=v1", "--branch"]) { [weak self] result in
            guard let self else { return }
            self.isRepository = result.status == 0
            if result.status == 0 {
                let status = GitService.parseStatus(result.output)
                self.branch = status.branch
                self.changes = status.changes
                self.message = nil
            } else {
                self.branch = ""
                self.changes = []
                self.message = "当前目录不是 Git 仓库"
            }
        }
    }

    func stage(_ change: GitChange) {
        perform(["add", "--", change.path])
    }

    func unstage(_ change: GitChange) {
        perform(["reset", "HEAD", "--", change.path])
    }

    func stageAll() { perform(["add", "-A"]) }
    func unstageAll() { perform(["reset", "HEAD"]) }

    func commit(message commitMessage: String, completion: @escaping (Bool) -> Void) {
        perform(["commit", "-m", commitMessage], completion: completion)
    }

    private func perform(_ arguments: [String], completion: ((Bool) -> Void)? = nil) {
        run(arguments) { [weak self] result in
            guard let self else { return }
            let succeeded = result.status == 0
            self.message = succeeded ? nil : result.error.trimmingCharacters(in: .whitespacesAndNewlines)
            completion?(succeeded)
            self.refresh()
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
