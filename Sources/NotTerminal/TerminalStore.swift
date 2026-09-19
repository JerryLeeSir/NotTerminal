import AppKit
import Foundation
import GhosttyTerminal

@MainActor
final class TerminalStore: ObservableObject {
    private static let workspaceDirectoriesKey = "workspaceDirectories"

    @Published private(set) var workspaces: [Workspace] = []
    @Published var selectedWorkspaceID: UUID?

    let controller: TerminalController

    init() {
        self.controller = TerminalController.shared
        self.restoreWorkspaces()

        if let firstWorkspace = workspaces.first {
            selectedWorkspaceID = firstWorkspace.id
            addTab(to: firstWorkspace)
        }
    }

    var selectedWorkspace: Workspace? {
        workspaces.first { $0.id == selectedWorkspaceID }
    }

    var selectedTab: TerminalTab? {
        selectedWorkspace?.selectedTab
    }

    func chooseWorkspaceDirectory() {
        let panel = NSOpenPanel()
        panel.title = "选择工作空间目录"
        panel.message = "该工作空间中的所有新终端都会从此目录启动。"
        panel.prompt = "创建工作空间"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = selectedWorkspace?.directory
            ?? FileManager.default.homeDirectoryForCurrentUser

        guard panel.runModal() == .OK, let directory = panel.url else { return }
        createWorkspace(directory: directory)
    }

    func createWorkspace(directory: URL) {
        let standardizedDirectory = directory.standardizedFileURL

        if let existingWorkspace = workspaces.first(where: {
            $0.directory == standardizedDirectory
        }) {
            select(existingWorkspace)
            return
        }

        let workspace = Workspace(directory: standardizedDirectory)
        workspaces.append(workspace)
        select(workspace)
        saveWorkspaces()
    }

    func select(_ workspace: Workspace) {
        selectedWorkspaceID = workspace.id
        workspace.project.git.refresh()

        if workspace.tabs.isEmpty {
            addTab(to: workspace)
        }
    }

    @discardableResult
    func addTab() -> TerminalTab? {
        guard let workspace = selectedWorkspace else { return nil }
        return addTab(to: workspace)
    }

    @discardableResult
    func addTab(to workspace: Workspace) -> TerminalTab? {
        guard workspaces.contains(where: { $0 === workspace }) else { return nil }

        let tab = TerminalTab(
            controller: controller,
            workingDirectory: workspace.directory.path
        ) { [weak self] tab in
            self?.close(tab: tab)
        }

        workspace.tabs.append(tab)
        workspace.selectedTabID = tab.id
        workspace.contentMode = .terminal
        return tab
    }

    func close(tab: TerminalTab) {
        guard let workspace = workspaces.first(where: { workspace in
            workspace.tabs.contains { $0.id == tab.id }
        }), let index = workspace.tabs.firstIndex(where: { $0.id == tab.id }) else {
            return
        }

        workspace.tabs.remove(at: index)

        if workspace.selectedTabID == tab.id {
            if index < workspace.tabs.count {
                workspace.selectedTabID = workspace.tabs[index].id
            } else {
                workspace.selectedTabID = workspace.tabs.last?.id
            }
        }
    }

    func select(_ tab: TerminalTab) {
        guard let workspace = selectedWorkspace,
              workspace.tabs.contains(where: { $0.id == tab.id }) else {
            return
        }

        workspace.selectedTabID = tab.id
        workspace.contentMode = .terminal
    }

    func close(workspace: Workspace) {
        guard let index = workspaces.firstIndex(where: { $0.id == workspace.id }) else {
            return
        }

        let wasSelected = workspace.id == selectedWorkspaceID
        workspace.tabs.removeAll()
        workspaces.remove(at: index)

        if wasSelected {
            if workspaces.indices.contains(index) {
                select(workspaces[index])
            } else if let last = workspaces.last {
                select(last)
            } else {
                selectedWorkspaceID = nil
            }
        }

        saveWorkspaces()
    }

    private func restoreWorkspaces() {
        let paths = UserDefaults.standard.stringArray(
            forKey: Self.workspaceDirectoriesKey
        ) ?? []

        workspaces = paths.compactMap { path in
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                return nil
            }
            return Workspace(directory: URL(fileURLWithPath: path))
        }
    }

    private func saveWorkspaces() {
        UserDefaults.standard.set(
            workspaces.map { $0.directory.path },
            forKey: Self.workspaceDirectoriesKey
        )
    }
}
