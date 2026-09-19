import Combine
import Foundation

@MainActor
final class Workspace: ObservableObject, Identifiable {
    let id = UUID()
    let directory: URL

    @Published var tabs: [TerminalTab] = []
    @Published var selectedTabID: UUID?

    init(directory: URL) {
        self.directory = directory.standardizedFileURL
    }

    var name: String {
        directory.lastPathComponent
    }

    var selectedTab: TerminalTab? {
        tabs.first { $0.id == selectedTabID }
    }
}
