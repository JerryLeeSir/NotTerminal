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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pagePosition: CGFloat = 0
    @State private var previousWorkspaceID: UUID?
    @State private var visibleWorkspaceIDs: Set<UUID> = []
    @State private var visibilityCleanupTask: Task<Void, Never>?

    var body: some View {
        if store.workspaces.isEmpty {
            EmptyStateView()
        } else {
            GeometryReader { geometry in
                let selectedIndex = store.workspaces.firstIndex {
                    $0.id == store.selectedWorkspaceID
                } ?? 0

                ZStack {
                    ForEach(Array(store.workspaces.enumerated()), id: \.element.id) { index, workspace in
                        let isActive = index == selectedIndex

                        WorkspaceDetail(
                            workspace: workspace,
                            isVisibleWorkspace: visibleWorkspaceIDs.contains(workspace.id) || isActive,
                            isActiveWorkspace: isActive
                        )
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .offset(
                            x: (CGFloat(index) - pagePosition) * geometry.size.width
                        )
                        .allowsHitTesting(isActive)
                        .accessibilityHidden(!isActive)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .onAppear {
                    pagePosition = CGFloat(selectedIndex)
                    previousWorkspaceID = store.selectedWorkspaceID
                    visibleWorkspaceIDs = Set([store.selectedWorkspaceID].compactMap { $0 })
                }
                .onChange(of: store.selectedWorkspaceID) { selectedWorkspaceID in
                    beginTransition(
                        to: selectedIndex,
                        selectedWorkspaceID: selectedWorkspaceID
                    )
                }
                .onDisappear {
                    visibilityCleanupTask?.cancel()
                }
            }
        }
    }

    private func beginTransition(
        to index: Int,
        selectedWorkspaceID: UUID?
    ) {
        visibilityCleanupTask?.cancel()

        visibleWorkspaceIDs = Set(
            [previousWorkspaceID, selectedWorkspaceID].compactMap { $0 }
        )
        previousWorkspaceID = selectedWorkspaceID

        guard !reduceMotion else {
            pagePosition = CGFloat(index)
            visibleWorkspaceIDs = Set([selectedWorkspaceID].compactMap { $0 })
            return
        }

        withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.88)) {
            pagePosition = CGFloat(index)
        }

        visibilityCleanupTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            visibleWorkspaceIDs = Set([selectedWorkspaceID].compactMap { $0 })
        }
    }
}

private struct WorkspaceDetail: View {
    @ObservedObject var workspace: Workspace
    let isVisibleWorkspace: Bool
    let isActiveWorkspace: Bool

    var body: some View {
        if workspace.selectedTab != nil {
            VStack(spacing: 0) {
                WorkspaceToolbar(workspace: workspace)
                Divider()
                TerminalTabsHost(
                    workspace: workspace,
                    isWorkspaceVisible: isVisibleWorkspace,
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
