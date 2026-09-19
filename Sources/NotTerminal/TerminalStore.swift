import Foundation
import GhosttyTerminal

@MainActor
final class TerminalStore: ObservableObject {
    private static let projectsRoot =
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/Project")

    @Published private(set) var tabs: [TerminalTab] = []
    @Published var selectedTabID: UUID?
    @Published private(set) var projects: [Project] = []

    let controller: TerminalController

    init() {
        self.controller = TerminalController.shared
        self.refreshProjects()
    }

    var selectedTab: TerminalTab? {
        tabs.first { $0.id == selectedTabID }
    }

    func refreshProjects() {
        self.projects = Project.discover(from: Self.projectsRoot)
    }

    @discardableResult
    func addTab(workingDirectory: String? = nil) -> TerminalTab {
        let tab = TerminalTab(
            controller: controller,
            workingDirectory: workingDirectory
        ) { [weak self] tab in
            self?.close(tab: tab)
        }
        tabs.append(tab)
        selectedTabID = tab.id
        return tab
    }

    func close(tab: TerminalTab) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        tabs.remove(at: index)

        if selectedTabID == tab.id {
            if index < tabs.count {
                selectedTabID = tabs[index].id
            } else {
                selectedTabID = tabs.last?.id
            }
        }
    }

    func select(_ tab: TerminalTab) {
        selectedTabID = tab.id
    }
}