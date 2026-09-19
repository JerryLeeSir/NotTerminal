import SwiftUI

struct Sidebar: View {
    @EnvironmentObject private var store: TerminalStore

    var body: some View {
        List {
            Section("Projects") {
                ForEach(store.projects) { project in
                    ProjectRow(project: project)
                }
            }

            Section("Terminals") {
                ForEach(store.tabs) { tab in
                    TerminalSidebarRow(tab: tab)
                }
            }

            Section("Toolbox") {
                Label("Files", systemImage: "folder")
                    .foregroundStyle(.secondary)
                Label("Git", systemImage: "arrow.triangle.branch")
                    .foregroundStyle(.secondary)
                Label("SSH", systemImage: "lock.shield")
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            Button {
                store.addTab()
            } label: {
                Label("新建终端", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(10)
        }
    }
}

struct ProjectRow: View {
    @EnvironmentObject private var store: TerminalStore
    @State private var hovered = false
    let project: Project

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .foregroundStyle(.tint)
                .font(.system(size: 12))

            Text(project.name)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)

            if hovered {
                Image(systemName: "terminal")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onHover { hovering in
            hovered = hovering
        }
        .onTapGesture {
            store.addTab(workingDirectory: project.url.path)
        }
        .help("在 \(project.name) 中打开终端")
    }
}

struct TerminalSidebarRow: View {
    @EnvironmentObject private var store: TerminalStore
    @ObservedObject var tab: TerminalTab
    @State private var hovered = false

    private var isSelected: Bool {
        tab.id == store.selectedTabID
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "terminal")
                .font(.system(size: 12))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

            Text(tab.title)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if hovered {
                Button {
                    store.close(tab: tab)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("关闭终端")
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(
            isSelected ? Color.accentColor.opacity(0.18) : Color.clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            hovered = hovering
        }
        .onTapGesture {
            store.select(tab)
        }
    }
}
