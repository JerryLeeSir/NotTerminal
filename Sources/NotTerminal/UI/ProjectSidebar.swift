import AppKit
import SwiftUI

struct ProjectSidebar: View {
    @ObservedObject var workspace: Workspace
    @ObservedObject private var project: ProjectSession

    init(workspace: Workspace) {
        self.workspace = workspace
        self.project = workspace.project
    }

    var body: some View {
        VStack(spacing: 0) {
            ProjectSectionPicker(project: project)
            Divider()

            switch project.sidebarSection {
            case .files:
                ProjectFilesView(project: project)
            case .commit:
                GitChangesView(project: project)
            }
        }
        .onAppear { project.activate() }
    }
}

private struct ProjectSectionPicker: View {
    @ObservedObject var project: ProjectSession

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ProjectSidebarSection.allCases) { section in
                Button {
                    project.sidebarSection = section
                    if section == .commit { project.git.refresh() }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: section.icon)
                        Text(section.title)
                    }
                    .font(.system(size: 11, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 27)
                    .background(
                        project.sidebarSection == section
                            ? Color.primary.opacity(0.09)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
    }
}

private struct ProjectFilesView: View {
    @ObservedObject var project: ProjectSession
    @ObservedObject private var root: ProjectFileNode

    init(project: ProjectSession) {
        self.project = project
        self.root = project.root
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(Color.accentColor)
                Text(project.directory.lastPathComponent)
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 2)
                Button {
                    project.refreshFiles()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("刷新文件树")
            }
            .padding(.horizontal, 9)
            .frame(height: 34)

            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if let children = root.children {
                        ForEach(children) { node in
                            ProjectFileRow(node: node, project: project, depth: 0)
                        }
                    } else if let error = root.loadError {
                        Text(error)
                            .font(.system(size: 10.5))
                            .foregroundStyle(.red)
                            .padding(10)
                    } else {
                        ProgressView().controlSize(.small).padding(12)
                    }
                }
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct ProjectFileRow: View {
    @ObservedObject var node: ProjectFileNode
    @ObservedObject var project: ProjectSession
    let depth: Int
    @State private var hovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                if node.isDirectory {
                    node.toggle()
                } else {
                    project.open(node.url)
                }
            } label: {
                HStack(spacing: 5) {
                    if node.isDirectory {
                        Image(systemName: node.isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8, weight: .semibold))
                            .frame(width: 8)
                    } else {
                        Color.clear.frame(width: 8, height: 1)
                    }

                    Image(systemName: iconName)
                        .font(.system(size: 11))
                        .foregroundStyle(iconColor)
                        .frame(width: 14)

                    Text(node.name)
                        .font(.system(size: 11.5))
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                }
                .padding(.leading, CGFloat(depth * 13 + 7))
                .padding(.trailing, 7)
                .frame(height: 25)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    isSelected
                        ? Color.accentColor.opacity(0.16)
                        : (hovered ? Color.primary.opacity(0.055) : Color.clear),
                    in: RoundedRectangle(cornerRadius: 5)
                )
                .padding(.horizontal, 3)
            }
            .buttonStyle(.plain)
            .onHover { hovered = $0 }

            if node.isDirectory, node.isExpanded, let children = node.children {
                ForEach(children) { child in
                    ProjectFileRow(node: child, project: project, depth: depth + 1)
                }
            }
        }
    }

    private var isSelected: Bool {
        project.selectedDocument?.url == node.url
    }

    private var iconName: String {
        if node.isDirectory { return node.isExpanded ? "folder.fill" : "folder" }
        switch node.url.pathExtension.lowercased() {
        case "swift": return "swift"
        case "json", "yaml", "yml", "toml": return "curlybraces"
        case "md", "txt": return "doc.text"
        case "png", "jpg", "jpeg", "gif", "svg": return "photo"
        case "sh", "zsh", "bash": return "terminal"
        default: return "doc"
        }
    }

    private var iconColor: Color {
        if node.isDirectory { return .accentColor.opacity(0.85) }
        switch node.url.pathExtension.lowercased() {
        case "swift": return .orange
        case "json", "yaml", "yml", "toml": return .yellow
        case "md": return .blue
        default: return .secondary
        }
    }
}

private struct GitChangesView: View {
    @ObservedObject var project: ProjectSession
    @ObservedObject private var git: GitRepository
    @State private var commitMessage = ""

    init(project: ProjectSession) {
        self.project = project
        self.git = project.git
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundStyle(.secondary)
                Text(git.branch.isEmpty ? "Git" : git.branch)
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                if git.isBusy { ProgressView().controlSize(.mini) }
                Button { git.refresh() } label: {
                    Image(systemName: "arrow.clockwise").frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 9)
            .frame(height: 34)

            Divider()

            if !git.isRepository {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 25))
                        .foregroundStyle(.tertiary)
                    Text("当前目录不是 Git 仓库")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        GitChangeSection(
                            title: "更改",
                            changes: git.changes.filter(\.isUnstaged),
                            actionTitle: "全部暂存",
                            action: git.stageAll,
                            rowAction: git.stage,
                            open: open
                        )
                        GitChangeSection(
                            title: "已暂存",
                            changes: git.changes.filter(\.isStaged),
                            actionTitle: "全部取消",
                            action: git.unstageAll,
                            rowAction: git.unstage,
                            open: open
                        )
                    }
                }

                Divider()

                VStack(spacing: 7) {
                    TextEditor(text: $commitMessage)
                        .font(.system(size: 11))
                        .scrollContentBackground(.hidden)
                        .padding(5)
                        .frame(height: 58)
                        .background(Color(nsColor: .textBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 5))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.primary.opacity(0.12)))

                    Button("提交 \(git.changes.filter(\.isStaged).count) 个文件") {
                        let message = commitMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                        git.commit(message: message) { succeeded in
                            if succeeded { commitMessage = "" }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
                    .disabled(
                        commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || git.changes.allSatisfy { !$0.isStaged }
                            || git.isBusy
                    )

                    if let message = git.message, !message.isEmpty {
                        Text(message)
                            .font(.system(size: 10))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(3)
                    }
                }
                .padding(8)
            }
        }
    }

    private func open(_ change: GitChange) {
        project.open(project.directory.appendingPathComponent(change.path))
    }
}

private struct GitChangeSection: View {
    let title: String
    let changes: [GitChange]
    let actionTitle: String
    let action: () -> Void
    let rowAction: (GitChange) -> Void
    let open: (GitChange) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                Text("\(changes.count)")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                if !changes.isEmpty {
                    Button(actionTitle, action: action)
                        .buttonStyle(.plain)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 9)
            .frame(height: 30)

            ForEach(changes) { change in
                HStack(spacing: 6) {
                    Button { open(change) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "doc")
                                .foregroundStyle(.secondary)
                            Text((change.path as NSString).lastPathComponent)
                                .lineLimit(1)
                            Spacer(minLength: 2)
                            Text(change.badge)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(change.badge == "D" ? .red : .green)
                        }
                        .font(.system(size: 11))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button { rowAction(change) } label: {
                        Image(systemName: title == "更改" ? "plus" : "minus")
                            .font(.system(size: 9, weight: .semibold))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help(title == "更改" ? "暂存" : "取消暂存")
                }
                .padding(.leading, 11)
                .padding(.trailing, 7)
                .frame(height: 27)
            }
        }
    }
}

struct ProjectBranchButton: View {
    @ObservedObject private var git: GitRepository
    private let openCommit: () -> Void
    @State private var isPresented = false
    @State private var hovered = false

    init(project: ProjectSession, openCommit: @escaping () -> Void = {}) {
        self.git = project.git
        self.openCommit = openCommit
    }

    var body: some View {
        Button {
            isPresented.toggle()
            if isPresented { git.refreshBranches() }
        } label: {
            HStack(spacing: 4) {
                GitBranchGlyph()
                Text(git.branch.isEmpty ? "Branch" : git.branch)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .frame(height: 24)
            .frame(maxWidth: 140)
            .background(
                hovered ? Color.primary.opacity(0.08) : Color.clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .onAppear { git.refresh() }
        .help("Switch Git branch")
        .background(
            BranchDropdownPresenter(
                isPresented: $isPresented,
                git: git,
                openCommit: openCommit,
                onDismiss: { isPresented = false }
            )
        )
        .sheet(
            item: Binding(
                get: { git.comparison },
                set: { if $0 == nil { git.dismissComparison() } }
            )
        ) { comparison in
            GitComparisonSheet(comparison: comparison) {
                git.dismissComparison()
            }
        }
    }
}

private struct BranchDropdownPresenter: NSViewRepresentable {
    @Binding var isPresented: Bool
    let git: GitRepository
    let openCommit: () -> Void
    let onDismiss: () -> Void

    func makeNSView(context: Context) -> BranchDropdownView {
        let view = BranchDropdownView()
        view.onDismiss = onDismiss
        view.openCommit = openCommit
        return view
    }

    func updateNSView(_ view: BranchDropdownView, context: Context) {
        view.onDismiss = onDismiss
        view.openCommit = openCommit
        view.updatePresentation(isPresented: isPresented, git: git)
    }
}

private final class BranchDropdownView: NSView {
    var onDismiss: (() -> Void)?
    var openCommit: (() -> Void)?

    private var panel: BranchDropdownPanel?
    private var actionPanel: BranchDropdownPanel?
    private var actionTarget: GitReference?
    private var mouseMonitor: Any?
    private var applicationDeactivationObserver: NSObjectProtocol?

    deinit {
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        if let applicationDeactivationObserver {
            NotificationCenter.default.removeObserver(applicationDeactivationObserver)
        }
        panel?.orderOut(nil)
        actionPanel?.orderOut(nil)
    }

    func updatePresentation(isPresented: Bool, git: GitRepository) {
        if isPresented {
            present(git: git)
        } else {
            dismiss()
        }
    }

    // MARK: - Presentation

    /// Slack between the panel edge and the dropdown, reserved for the window
    /// shadow. A shadow drawn inside a SwiftUI view is clipped away: the hosting
    /// view's frame equals the panel's content rect, so anything painted outside
    /// the content bounds never reaches the screen.
    private static let shadowMargin: CGFloat = 16

    private func present(git: GitRepository) {
        guard panel == nil, let window else { return }

        let margin = Self.shadowMargin
        let screen = window.screen ?? NSScreen.main
        let availableHeight = screen?.visibleFrame.height ?? 800
        let maximumHeight = max(360, min(780, availableHeight - 12 - margin * 2))
        let hosting = makeHosting(git: git, maximumHeight: maximumHeight)
        let size = hosting.fittingSize
        let panelSize = NSSize(width: size.width + margin * 2, height: size.height + margin * 2)
        hosting.frame = NSRect(
            x: margin,
            y: margin,
            width: size.width,
            height: size.height
        )

        let panel = BranchDropdownPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // Let AppKit draw the shadow from the hosting view's alpha channel
        // rather than compositing one inside a view that gets clipped.
        panel.hasShadow = true
        panel.hidesOnDeactivate = true
        panel.isExcludedFromWindowsMenu = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.level = .popUpMenu
        self.panel = panel

        let buttonRect = convert(bounds, to: nil)
        let screenOrigin = window.convertPoint(toScreen: buttonRect.origin)

        // Align the dropdown itself (not the shadow slack) with the button.
        var originX = screenOrigin.x - margin
        var originY = screenOrigin.y - size.height - margin
        if let screen {
            let visibleFrame = screen.visibleFrame
            originY = max(originY, visibleFrame.minY)
            originX = max(originX, visibleFrame.minX)
            if originX + panelSize.width > visibleFrame.maxX {
                originX = max(visibleFrame.maxX - panelSize.width, visibleFrame.minX)
            }
            if originY + panelSize.height > visibleFrame.maxY {
                originY = max(visibleFrame.maxY - panelSize.height, visibleFrame.minY)
            }
        }

        panel.setFrame(
            NSRect(x: originX, y: originY, width: panelSize.width, height: panelSize.height),
            display: true
        )
        panel.makeKeyAndOrderFront(nil)

        installMonitorIfNeeded()
        installApplicationDeactivationObserverIfNeeded()
    }

    // MARK: - Second level

    /// Opens the action window flush to the right of the list panel, vertically
    /// aligned with the row that was clicked, so the list stays visible and
    /// keeps showing which branch the actions belong to.
    private func openActions(for reference: GitReference, rowRect: CGRect, git: GitRepository) {
        closeActions()
        guard let panel else { return }
        actionTarget = reference

        let margin = Self.shadowMargin
        // Width comes from the longest action title, so the window hugs its
        // content instead of guessing a fixed size.
        let content = BranchActionPanel(
            reference: reference,
            git: git,
            dismissAll: { [weak self] in
                guard let self else { return }
                self.closeActions()
                self.dismiss()
                self.onDismiss?()
            },
            closeActions: { [weak self] in self?.closeActions() }
        )
        let hosting = NSHostingView(
            rootView: AnyView(
                content
                    .background(Color(nsColor: .windowBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                    }
            )
        )
        let size = hosting.fittingSize
        let panelSize = NSSize(width: size.width + margin * 2, height: size.height + margin * 2)
        hosting.frame = NSRect(x: margin, y: margin, width: size.width, height: size.height)

        let actionPanel = BranchDropdownPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        actionPanel.contentView = hosting
        actionPanel.isOpaque = false
        actionPanel.backgroundColor = .clear
        actionPanel.hasShadow = true
        // Matches the list panel: both hide when the app loses focus, which is
        // covered explicitly by the `didResignActive` observer too.
        actionPanel.hidesOnDeactivate = true
        actionPanel.isExcludedFromWindowsMenu = true
        actionPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        actionPanel.level = .popUpMenu
        self.actionPanel = actionPanel

        let placement = ActionPanelPlacement(
            listFrame: panel.frame,
            rowRect: rowRect,
            panelSize: panelSize,
            margin: margin,
            visibleFrame: (panel.screen ?? NSScreen.main)?.visibleFrame
        )
        let origin = placement.origin()
        actionPanel.setFrame(
            NSRect(origin: origin, size: panelSize),
            display: true
        )
        // Takes key status so the sheets this window presents (New Branch has
        // a text field) receive keyboard input. Safe for the list: neither
        // panel hides on deactivate any more, so losing key does not hide it.
        actionPanel.makeKeyAndOrderFront(nil)
    }

    private func closeActions() {
        actionPanel?.orderOut(nil)
        actionPanel = nil
        actionTarget = nil
    }

    private func makeHosting(
        git: GitRepository,
        maximumHeight: CGFloat
    ) -> NSHostingView<AnyView> {
        NSHostingView(
            rootView: AnyView(
                EnhancedBranchPopover(
                    git: git,
                    maximumHeight: maximumHeight,
                    openActions: { [weak self] reference, rowRect in
                        self?.openActions(for: reference, rowRect: rowRect, git: git)
                    },
                    dismiss: { [weak self] in
                        guard let self else { return }
                        self.dismiss()
                        self.onDismiss?()
                    },
                    openCommit: { [weak self] in self?.openCommit?() }
                )
                .frame(width: 360)
                .background(Color(nsColor: .windowBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                }
            )
        )
    }

    private func dismiss() {
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        mouseMonitor = nil
        if let applicationDeactivationObserver {
            NotificationCenter.default.removeObserver(applicationDeactivationObserver)
        }
        applicationDeactivationObserver = nil
        closeActions()
        panel?.orderOut(nil)
        panel = nil
    }

    // MARK: - Outside click

    private func installMonitorIfNeeded() {
        guard mouseMonitor == nil else { return }
        mouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            self?.handleMouseEvent(event)
        }
    }

    private func installApplicationDeactivationObserverIfNeeded() {
        guard applicationDeactivationObserver == nil else { return }
        applicationDeactivationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.dismiss()
            self.onDismiss?()
        }
    }

    private func handleMouseEvent(_ event: NSEvent) -> NSEvent? {
        guard let panel, panel.isVisible else { return event }

        let isInsideAnchor: Bool
        if event.window === window {
            isInsideAnchor = bounds.contains(convert(event.locationInWindow, from: nil))
        } else {
            isInsideAnchor = false
        }

        let policy = OutsideClickPolicy(
            listPanel: panel,
            actionPanel: actionPanel,
            anchorWindow: window,
            isInsideAnchor: isInsideAnchor
        )
        guard policy.shouldDismiss(eventWindow: event.window) else { return event }

        dismiss()
        onDismiss?()
        return event
    }
}

/// Decides whether a mouse-down closes the dropdown. Pulled out of the view so
/// the nil-handling is testable: comparing optional windows with `===` treats
/// two nils as equal, so a sheet of the *absent* second-level window would
/// otherwise look like a click on the dropdown itself.
struct OutsideClickPolicy {
    let listPanel: NSWindow
    let actionPanel: NSWindow?
    /// The view the dropdown hangs off, in the app's main window.
    let anchorWindow: NSWindow?
    /// Whether the click landed within that view's bounds.
    let isInsideAnchor: Bool

    func shouldDismiss(eventWindow: NSWindow?) -> Bool {
        if let eventWindow, belongsToDropdown(eventWindow) { return false }
        // The button itself toggles the dropdown; let the event through.
        if eventWindow === anchorWindow, isInsideAnchor { return false }
        return true
    }

    /// Walks up from `window` through sheet and child relationships, so a sheet
    /// or attached window of either panel counts as part of the dropdown.
    private func belongsToDropdown(_ window: NSWindow) -> Bool {
        var candidate: NSWindow? = window
        // Bounded: window parent chains are shallow, and this guards against a
        // malformed cycle turning an outside click into a hang.
        for _ in 0..<8 {
            guard let current = candidate else { return false }
            if current === listPanel { return true }
            // Explicit unwrap: `nil === nil` is true, so comparing optionals
            // here would classify every plain window as belonging to the
            // dropdown whenever the second level is closed.
            if let actionPanel, current === actionPanel { return true }
            candidate = current.sheetParent ?? current.parent
        }
        return false
    }
}

/// Where to park the second-level window so it sits flush beside the list,
/// top-aligned with the row that was clicked. Pure so it can be tested without
/// standing up windows.
struct ActionPanelPlacement {
    /// The list panel's frame, in screen coordinates, including its shadow slack.
    let listFrame: NSRect
    /// The clicked row, in the list window's own coordinates.
    let rowRect: NSRect
    /// The action panel's frame size, including its own shadow slack.
    let panelSize: NSSize
    /// Shadow slack insets, equal on both panels.
    let margin: CGFloat
    let visibleFrame: NSRect?

    /// Gap between the two panels' *visible* edges. Each window's frame is
    /// inflated by `margin` on every side, so the frames must overlap by
    /// `2 * margin` minus this gap for the visible edges to nearly touch.
    private static let gap: CGFloat = 4

    func origin() -> NSPoint {
        // Visible content of each window, in screen coordinates.
        let listVisibleRight = listFrame.maxX - margin
        let listVisibleLeft = listFrame.minX + margin
        let rowTop = listFrame.minY + rowRect.maxY

        var x = listVisibleRight + Self.gap - margin
        // The action window's content starts `margin` above its frame origin,
        // so back that out to top-align the content with the clicked row.
        var y = rowTop - panelSize.height + margin

        if let visibleFrame {
            if x + panelSize.width - margin > visibleFrame.maxX {
                // No room to the right: sit to the left of the list instead.
                x = listVisibleLeft - Self.gap - panelSize.width + margin
            }
            x = max(x, visibleFrame.minX)
            y = min(max(y, visibleFrame.minY), visibleFrame.maxY - panelSize.height)
        }
        return NSPoint(x: x, y: y)
    }
}

private final class BranchDropdownPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private struct GitBranchGlyph: View {
    var body: some View {
        GitBranchGlyphShape()
            .stroke(
                Color.secondary,
                style: StrokeStyle(lineWidth: 1.45, lineCap: .round, lineJoin: .round)
            )
            .frame(width: 14, height: 15)
            .accessibilityHidden(true)
    }
}

private struct GitBranchGlyphShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scaleX = rect.width / 14
        let scaleY = rect.height / 15
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scaleX, y: rect.minY + y * scaleY)
        }

        var path = Path()
        path.addEllipse(
            in: CGRect(
                x: rect.minX + 0.75 * scaleX,
                y: rect.minY + 0.75 * scaleY,
                width: 5 * scaleX,
                height: 5 * scaleY
            )
        )
        path.addEllipse(
            in: CGRect(
                x: rect.minX + 8.25 * scaleX,
                y: rect.minY + 2.75 * scaleY,
                width: 5 * scaleX,
                height: 5 * scaleY
            )
        )
        path.move(to: point(3.25, 5.75))
        path.addLine(to: point(3.25, 14.25))
        path.move(to: point(3.25, 8.25))
        path.addCurve(
            to: point(8.25, 5.25),
            control1: point(6.5, 8.25),
            control2: point(7.2, 5.25)
        )
        return path
    }
}
