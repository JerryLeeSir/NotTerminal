import SwiftUI

struct Sidebar: View {
    @EnvironmentObject private var store: TerminalStore

    private let workspaceColumns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]

    var body: some View {
        VStack(spacing: 0) {
            workspaceSection
            Divider()
            WorkspaceTabsPager()
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var workspaceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("工作空间")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    store.chooseWorkspaceDirectory()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("选择目录并新建工作空间")
            }

            LazyVGrid(columns: workspaceColumns, alignment: .center, spacing: 6) {
                ForEach(store.workspaces) { workspace in
                    WorkspaceTile(
                        workspace: workspace,
                        isSelected: workspace.id == store.selectedWorkspaceID
                    )
                }
            }
        }
        .padding(8)
    }

}

private struct WorkspaceTabsPager: View {
    @EnvironmentObject private var store: TerminalStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pagePosition: CGFloat = 0

    var body: some View {
        if store.workspaces.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 24))
                    .foregroundStyle(.tertiary)
                Text("选择目录创建工作空间")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            GeometryReader { geometry in
                let selectedIndex = store.workspaces.firstIndex {
                    $0.id == store.selectedWorkspaceID
                } ?? 0

                ZStack {
                    ForEach(Array(store.workspaces.enumerated()), id: \.element.id) { index, workspace in
                        let isActive = index == selectedIndex

                        WorkspaceTabs(workspace: workspace)
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
                }
                .onChange(of: store.selectedWorkspaceID) { workspaceID in
                    guard let workspaceID,
                          let newIndex = store.workspaces.firstIndex(where: {
                              $0.id == workspaceID
                          }) else {
                        return
                    }

                    animate(to: newIndex)
                }
            }
        }
    }

    private func animate(to index: Int) {
        guard !reduceMotion else {
            pagePosition = CGFloat(index)
            return
        }

        withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.88)) {
            pagePosition = CGFloat(index)
        }
    }

}

private struct WorkspaceTile: View {
    @EnvironmentObject private var store: TerminalStore
    @ObservedObject var workspace: Workspace
    let isSelected: Bool

    var body: some View {
        Button {
            store.select(workspace)
        } label: {
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    isSelected
                        ? Color.accentColor.opacity(0.16)
                        : Color(nsColor: .windowBackgroundColor)
                )
                .aspectRatio(64 / 38, contentMode: .fit)
                .overlay {
                    Text(workspace.name.prefix(1).uppercased())
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            isSelected
                                ? Color.accentColor.opacity(0.65)
                                : Color.primary.opacity(0.08),
                            lineWidth: 1
                        )
                }
            }
        .buttonStyle(.plain)
        .help(workspace.directory.path)
        .accessibilityLabel("工作空间：\(workspace.name)")
    }
}

private struct WorkspaceTabs: View {
    @EnvironmentObject private var store: TerminalStore
    @ObservedObject var workspace: Workspace

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(workspace.name)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)

                Spacer(minLength: 4)

                Button {
                    store.addTab(to: workspace)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("在 \(workspace.name) 中新建终端")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(workspace.tabs) { tab in
                        TerminalSidebarRow(
                            tab: tab,
                            isSelected: tab.id == workspace.selectedTabID
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
    }
}

private struct TerminalSidebarRow: View {
    @EnvironmentObject private var store: TerminalStore
    @ObservedObject var tab: TerminalTab
    @State private var hovered = false
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "terminal")
                .font(.system(size: 11))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

            Text(tab.title)
                .lineLimit(1)
                .truncationMode(.middle)
                .font(.system(size: 12))
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                store.close(tab: tab)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .opacity(hovered || isSelected ? 1 : 0)
            .help("关闭终端")
        }
        .padding(.horizontal, 9)
        .frame(height: 34)
        .background(
            isSelected ? Color.primary.opacity(0.09) : Color.clear,
            in: RoundedRectangle(cornerRadius: 7)
        )
        .contentShape(RoundedRectangle(cornerRadius: 7))
        .onHover { hovered = $0 }
        .onTapGesture {
            store.select(tab)
        }
    }
}
