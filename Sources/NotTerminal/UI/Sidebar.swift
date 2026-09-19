import SwiftUI

struct Sidebar: View {
    @EnvironmentObject private var store: TerminalStore

    private let workspaceColumns = [
        GridItem(.adaptive(minimum: 58, maximum: 72), spacing: 8)
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
        VStack(alignment: .leading, spacing: 10) {
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

            LazyVGrid(columns: workspaceColumns, alignment: .leading, spacing: 8) {
                ForEach(store.workspaces) { workspace in
                    WorkspaceTile(
                        workspace: workspace,
                        isSelected: workspace.id == store.selectedWorkspaceID
                    )
                }

                AddWorkspaceTile()
            }
        }
        .padding(12)
    }

}

private struct WorkspaceTabsPager: View {
    @EnvironmentObject private var store: TerminalStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                            .offset(x: CGFloat(index - selectedIndex) * geometry.size.width)
                            .allowsHitTesting(isActive)
                            .accessibilityHidden(!isActive)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.32),
                    value: store.selectedWorkspaceID
                )
            }
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
            VStack(spacing: 5) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

                Text(workspace.name)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(
                isSelected ? Color.accentColor.opacity(0.16) : Color(nsColor: .windowBackgroundColor),
                in: RoundedRectangle(cornerRadius: 9)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(
                        isSelected ? Color.accentColor.opacity(0.65) : Color.primary.opacity(0.08),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .help(workspace.directory.path)
        .accessibilityLabel("工作空间：\(workspace.name)")
    }
}

private struct AddWorkspaceTile: View {
    @EnvironmentObject private var store: TerminalStore

    var body: some View {
        Button {
            store.chooseWorkspaceDirectory()
        } label: {
            VStack(spacing: 5) {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .medium))
                Text("新建")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(
                Color(nsColor: .windowBackgroundColor),
                in: RoundedRectangle(cornerRadius: 9)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .help("选择目录并新建工作空间")
    }
}

private struct WorkspaceTabs: View {
    @EnvironmentObject private var store: TerminalStore
    @ObservedObject var workspace: Workspace

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workspace.name)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)

                    Text(workspace.directory.path)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 4)

                Button {
                    store.addTab()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
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
