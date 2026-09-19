import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: TerminalStore

    var body: some View {
        HSplitView {
            Sidebar()
                .frame(minWidth: 200, idealWidth: 240, maxWidth: 360)

            WorkspacePager()
            .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct WorkspacePager: View {
    @EnvironmentObject private var store: TerminalStore

    var body: some View {
        if store.workspaces.isEmpty {
            EmptyStateView()
        } else {
            ZStack {
                ForEach(store.workspaces) { workspace in
                    let isActive = workspace.id == store.selectedWorkspaceID

                    WorkspaceDetail(
                        workspace: workspace,
                        isActiveWorkspace: isActive
                    )
                    .opacity(isActive ? 1 : 0)
                    .allowsHitTesting(isActive)
                    .accessibilityHidden(!isActive)
                    .zIndex(isActive ? 1 : 0)
                }
            }
        }
    }
}

private struct WorkspaceDetail: View {
    @ObservedObject var workspace: Workspace
    let isActiveWorkspace: Bool

    var body: some View {
        if workspace.selectedTab != nil {
            VStack(spacing: 0) {
                WorkspaceToolbar(workspace: workspace)
                Divider()
                TerminalTabsHost(
                    workspace: workspace,
                    isWorkspaceActive: isActiveWorkspace
                )
            }
        } else {
            EmptyStateView()
        }
    }
}

struct EmptyStateView: View {
    @EnvironmentObject private var store: TerminalStore

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: store.selectedWorkspace == nil ? "square.grid.2x2" : "terminal")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(store.selectedWorkspace == nil ? "还没有工作空间" : "没有打开的终端")
                .font(.headline)

            Text(
                store.selectedWorkspace == nil
                    ? "选择一个目录来创建工作空间。"
                    : "新终端会从当前工作空间目录启动。"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Button(store.selectedWorkspace == nil ? "选择目录" : "新建终端") {
                if store.selectedWorkspace == nil {
                    store.chooseWorkspaceDirectory()
                } else {
                    store.addTab()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
