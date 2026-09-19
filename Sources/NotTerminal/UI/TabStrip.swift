import GhosttyTerminal
import SwiftUI

struct TerminalTabsHost: View {
    @ObservedObject var workspace: Workspace
    let isWorkspaceActive: Bool
    @FocusState private var focusedTabID: UUID?

    var body: some View {
        ZStack {
            ForEach(workspace.tabs) { tab in
                let isSelected = isWorkspaceActive && tab.id == workspace.selectedTabID

                TerminalSurfaceView(context: tab.state)
                    .terminalFocused($focusedTabID, equals: tab.id)
                    .opacity(isSelected ? 1 : 0)
                    .allowsHitTesting(isSelected)
                    .accessibilityHidden(!isSelected)
                    .zIndex(isSelected ? 1 : 0)
                    .onAppear {
                        tab.state.isSurfaceVisible = isSelected
                    }
                    .onChange(of: isSelected) { visible in
                        tab.state.isSurfaceVisible = visible
                    }
            }
        }
        .background(Color.black)
        .onAppear {
            updateFocus()
        }
        .onChange(of: workspace.selectedTabID) { selectedTabID in
            focusedTabID = isWorkspaceActive ? selectedTabID : nil
        }
        .onChange(of: isWorkspaceActive) { _ in
            updateFocus()
        }
    }

    private func updateFocus() {
        focusedTabID = isWorkspaceActive ? workspace.selectedTabID : nil
    }
}

struct WorkspaceToolbar: View {
    @EnvironmentObject private var store: TerminalStore
    @ObservedObject var workspace: Workspace

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder.fill")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Text(workspace.name)
                .font(.system(size: 12, weight: .semibold))

            Text(workspace.directory.path)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)

            Button {
                store.addTab()
            } label: {
                Label("新建终端", systemImage: "plus")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.borderless)
            .help("在当前工作空间中新建终端")
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
