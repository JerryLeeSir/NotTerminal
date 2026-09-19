import Combine
import Foundation

enum WorkspaceContentMode {
    case terminal
    case project
}

@MainActor
final class Workspace: ObservableObject, Identifiable {
    let id = UUID()
    let directory: URL

    @Published var tabs: [TerminalTab] = []
    @Published var selectedTabID: UUID?
    @Published var contentMode: WorkspaceContentMode = .terminal

    let project: ProjectSession

    init(directory: URL) {
        let directory = directory.standardizedFileURL
        self.directory = directory
        self.project = ProjectSession(directory: directory)
    }

    var name: String {
        directory.lastPathComponent
    }

    var selectedTab: TerminalTab? {
        tabs.first { $0.id == selectedTabID }
    }
}
