import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: TerminalStore
    @AppStorage("sidebarWidth") private var sidebarWidth: Double = 180

    private static let minimumSidebarWidth: CGFloat = 180
    private static let maximumSidebarWidth: CGFloat = 420
    private static let minimumContentWidth: CGFloat = 400

    var body: some View {
        GeometryReader { geometry in
            let maximum = max(
                Self.minimumSidebarWidth,
                min(
                    Self.maximumSidebarWidth,
                    geometry.size.width - Self.minimumContentWidth - SidebarSplitHandle.visibleThickness
                )
            )

            SidebarSplitView(
                storedWidth: CGFloat(sidebarWidth),
                minimum: Self.minimumSidebarWidth,
                maximum: maximum,
                onCommit: { sidebarWidth = Double($0) }
            ) {
                Sidebar()
            } content: {
                WorkspacePager()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

/// A two-pane horizontal split with a fixed leading width the user can drag and
/// that the host persists. The dragged width lives here so a divider move only
/// re-evaluates this container, not the AppKit-backed terminal/editor panes.
private struct SidebarSplitView<Leading: View, Trailing: View>: View {
    let storedWidth: CGFloat
    let minimum: CGFloat
    let maximum: CGFloat
    let onCommit: (CGFloat) -> Void

    private let leading: Leading
    private let trailing: Trailing

    @State private var draggedWidth: CGFloat?
    @State private var dragStart: CGFloat = 0

    init(
        storedWidth: CGFloat,
        minimum: CGFloat,
        maximum: CGFloat,
        onCommit: @escaping (CGFloat) -> Void,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder content: () -> Trailing
    ) {
        self.storedWidth = storedWidth
        self.minimum = minimum
        self.maximum = maximum
        self.onCommit = onCommit
        self.leading = leading()
        self.trailing = content()
    }

    private var resolvedWidth: CGFloat {
        clamped(draggedWidth ?? storedWidth)
    }

    var body: some View {
        HStack(spacing: 0) {
            leading
                .frame(width: resolvedWidth)
                .frame(maxHeight: .infinity)

            SidebarSplitHandle(
                onDragStarted: { dragStart = resolvedWidth },
                onDragChanged: { draggedWidth = clamped(dragStart + $0) },
                onDragEnded: { translation in
                    let final = clamped(dragStart + translation)
                    draggedWidth = nil
                    onCommit(final)
                }
            )

            trailing
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func clamped(_ value: CGFloat) -> CGFloat {
        min(max(value, minimum), maximum)
    }
}

/// The hit target is wider than the 1pt separator it draws, and its frame
/// overflows the reserved 1pt so the resize region reaches into both panes.
private struct SidebarSplitHandle: View {
    static let visibleThickness: CGFloat = 1
    static let hitThickness: CGFloat = 11

    let onDragStarted: () -> Void
    let onDragChanged: (CGFloat) -> Void
    let onDragEnded: (CGFloat) -> Void

    @State private var isHovering = false
    @State private var isDragging = false

    var body: some View {
        Rectangle()
            .fill(dividerColor)
            .frame(width: Self.visibleThickness)
            .frame(maxHeight: .infinity)
            .frame(width: Self.hitThickness)
            .overlay {
                SidebarSplitHandleInteraction(
                    onHoverChanged: { isHovering = $0 },
                    onDragStarted: {
                        isDragging = true
                        onDragStarted()
                    },
                    onDragChanged: onDragChanged,
                    onDragEnded: { translation in
                        isDragging = false
                        onDragEnded(translation)
                    }
                )
            }
            .frame(width: Self.visibleThickness)
            .zIndex(1)
            .help("拖动调整侧栏宽度")
    }

    private var dividerColor: Color {
        if isDragging || isHovering {
            return Color(nsColor: .secondaryLabelColor)
        }
        return Color(nsColor: .separatorColor)
    }
}

private struct SidebarSplitHandleInteraction: NSViewRepresentable {
    let onHoverChanged: (Bool) -> Void
    let onDragStarted: () -> Void
    let onDragChanged: (CGFloat) -> Void
    let onDragEnded: (CGFloat) -> Void

    func makeNSView(context: Context) -> SidebarSplitHandleView {
        let view = SidebarSplitHandleView()
        apply(to: view)
        return view
    }

    func updateNSView(_ view: SidebarSplitHandleView, context: Context) {
        apply(to: view)
    }

    private func apply(to view: SidebarSplitHandleView) {
        view.onHoverChanged = onHoverChanged
        view.onDragStarted = onDragStarted
        view.onDragChanged = onDragChanged
        view.onDragEnded = onDragEnded
    }
}

/// A transparent hit target that owns the resize cursor and forwards drags in
/// screen coordinates, so the handle resizing itself cannot skew the delta.
private final class SidebarSplitHandleView: NSView {
    var onHoverChanged: ((Bool) -> Void)?
    var onDragStarted: (() -> Void)?
    var onDragChanged: ((CGFloat) -> Void)?
    var onDragEnded: ((CGFloat) -> Void)?

    private var tracking: NSTrackingArea?
    private var dragStartX: CGFloat?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.cursorUpdate, .mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        tracking = area
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { dragStartX = nil }
    }

    override func cursorUpdate(with event: NSEvent) { NSCursor.resizeLeftRight.set() }
    override func mouseMoved(with event: NSEvent) { NSCursor.resizeLeftRight.set() }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.resizeLeftRight.set()
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged?(false)
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        dragStartX = window.convertPoint(toScreen: event.locationInWindow).x
        NSCursor.resizeLeftRight.set()
        onDragStarted?()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let translation = translation(for: event) else { return }
        NSCursor.resizeLeftRight.set()
        onDragChanged?(translation)
    }

    override func mouseUp(with event: NSEvent) {
        guard let translation = translation(for: event) else { return }
        dragStartX = nil
        onDragEnded?(translation)
    }

    private func translation(for event: NSEvent) -> CGFloat? {
        guard let window, let dragStartX else { return nil }
        return window.convertPoint(toScreen: event.locationInWindow).x - dragStartX
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
        if workspace.contentMode == .project {
            ProjectEditorView(workspace: workspace)
        } else if workspace.selectedTab != nil {
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
