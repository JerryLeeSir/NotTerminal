import AppKit
import SwiftUI

struct Sidebar: View {
    @EnvironmentObject private var store: TerminalStore
    @State private var addWorkspaceHovered = false

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
                        .background(
                            addWorkspaceHovered ? Color.primary.opacity(0.08) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 5)
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .onHover { addWorkspaceHovered = $0 }
                .help("选择目录并新建工作空间")
            }

            LazyVGrid(columns: workspaceColumns, alignment: .center, spacing: 6) {
                ForEach(Array(store.workspaces.enumerated()), id: \.element.id) { index, workspace in
                    WorkspaceTile(
                        workspace: workspace,
                        isSelected: workspace.id == store.selectedWorkspaceID,
                        palette: WorkspaceAccentPalette.at(index)
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
    @State private var hovered = false
    let isSelected: Bool
    let palette: WorkspaceAccentPalette

    var body: some View {
        Button {
            store.select(workspace)
        } label: {
            RoundedRectangle(cornerRadius: 10)
                .fill(palette.gradient)
                .aspectRatio(64 / 38, contentMode: .fit)
                .overlay {
                    Text(workspace.monogram)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            isSelected
                                ? Color.white.opacity(0.72)
                                : Color.black.opacity(0.16),
                            lineWidth: isSelected ? 1.4 : 0.7
                        )
                }
                .opacity(isSelected || hovered ? 1 : 0.88)
                .shadow(
                    color: isSelected ? palette.trailing.opacity(0.28) : .clear,
                    radius: 4,
                    y: 1
                )
            }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help(workspace.directory.path)
        .accessibilityLabel("工作空间：\(workspace.name)")
    }

}

private struct WorkspaceTabs: View {
    @EnvironmentObject private var store: TerminalStore
    @ObservedObject var workspace: Workspace
    @State private var headerHovered = false
    @State private var addTabHovered = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    workspace.contentMode = workspace.contentMode == .project
                        ? .terminal
                        : .project
                    if workspace.contentMode == .project {
                        workspace.project.activate()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: workspace.contentMode == .project ? "terminal" : "folder")
                            .font(.system(size: 10.5))
                            .foregroundStyle(workspace.contentMode == .project ? Color.secondary : Color.accentColor)
                        Text(workspace.name)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .layoutPriority(1)
                .help(workspace.contentMode == .project ? "返回终端列表" : "打开项目文件")

                Spacer(minLength: 4)

                if workspace.contentMode == .terminal {
                    Button {
                        store.addTab(to: workspace)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 26, height: 26)
                            .contentShape(Rectangle())
                            .background(
                                addTabHovered ? Color.primary.opacity(0.08) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 6)
                            )
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .onHover { addTabHovered = $0 }
                    .help("在 \(workspace.name) 中新建终端")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .background(
                headerHovered ? Color.primary.opacity(0.04) : Color.clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
            .background(
                HorizontalScrollCatcher { direction in
                    switchWorkspace(direction)
                }
            )
            .padding(.horizontal, 4)
            .onHover { headerHovered = $0 }

            if workspace.contentMode == .project {
                ProjectSidebar(workspace: workspace)
            } else {
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

    private func switchWorkspace(_ direction: Int) {
        guard let currentIndex = store.workspaces.firstIndex(where: {
            $0.id == workspace.id
        }) else {
            return
        }

        let targetIndex = currentIndex + direction
        guard store.workspaces.indices.contains(targetIndex) else { return }

        store.select(store.workspaces[targetIndex])
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
            isSelected
                ? Color.primary.opacity(0.09)
                : (hovered ? Color.primary.opacity(0.05) : Color.clear),
            in: RoundedRectangle(cornerRadius: 7)
        )
        .contentShape(RoundedRectangle(cornerRadius: 7))
        .onHover { hovered = $0 }
        .onTapGesture {
            store.select(tab)
        }
    }
}

private struct HorizontalScrollCatcher: NSViewRepresentable {
    let onSwipe: (Int) -> Void

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.onSwipe = onSwipe
        return view
    }

    func updateNSView(_ nsView: CatcherView, context: Context) {
        nsView.onSwipe = onSwipe
    }

    final class CatcherView: NSView {
        var onSwipe: ((Int) -> Void)?

        private var monitor: Any?
        private var accumulated: CGFloat = 0
        private var triggered = false

        // The view only observes trackpad scroll events. Let clicks pass through
        // to the workspace title and add-tab button rendered above it.
        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()

            if window != nil {
                installMonitorIfNeeded()
            } else {
                removeMonitor()
            }
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        private func installMonitorIfNeeded() {
            guard monitor == nil else { return }

            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) {
                [weak self] event in
                guard let self else { return event }
                return self.handle(event) ? nil : event
            }
        }

        private func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }

        private func handle(_ event: NSEvent) -> Bool {
            guard event.window === window else { return false }

            let location = convert(event.locationInWindow, from: nil)
            guard bounds.contains(location) else { return false }

            guard abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) else {
                return false
            }

            if event.phase == .began {
                accumulated = 0
                triggered = false
            }

            if event.phase == .began || event.phase == .changed {
                guard !triggered else { return true }
                accumulated += event.scrollingDeltaX

                let threshold: CGFloat = 30
                if accumulated <= -threshold {
                    triggered = true
                    onSwipe?(1)
                } else if accumulated >= threshold {
                    triggered = true
                    onSwipe?(-1)
                }
            }

            if event.phase == .ended || event.phase == .cancelled {
                accumulated = 0
                triggered = false
            }

            return true
        }
    }
}
