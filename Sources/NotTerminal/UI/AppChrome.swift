import AppKit
import SwiftUI

enum AppChromePalette {
    static let outer = adaptive(
        light: NSColor(srgbRed: 0.933, green: 0.945, blue: 0.961, alpha: 1),
        dark: NSColor(srgbRed: 0.157, green: 0.161, blue: 0.173, alpha: 1)
    )
    static let surface = adaptive(
        light: .white,
        dark: NSColor(srgbRed: 0.110, green: 0.114, blue: 0.122, alpha: 1)
    )
    static let border = adaptive(
        light: NSColor(srgbRed: 0.788, green: 0.800, blue: 0.824, alpha: 0.8),
        dark: NSColor(white: 1, alpha: 0.10)
    )
    static let control = adaptive(
        light: NSColor(white: 0, alpha: 0.055),
        dark: NSColor(white: 1, alpha: 0.065)
    )

    private static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
}

struct AppTopBar: View {
    @EnvironmentObject private var store: TerminalStore

    var body: some View {
        HStack(spacing: 10) {
            MacTrafficLightControls()

            if let workspace = store.selectedWorkspace {
                WorkspaceTopBarInfo(workspace: workspace)
                ProjectBranchButton(project: workspace.project)
            }

            Spacer(minLength: 18)

            if let workspace = store.selectedWorkspace {
                WorkspaceTopBarCenter(workspace: workspace)
            }

            Spacer(minLength: 18)

            Button {
                store.addTab()
            } label: {
                Label("新建终端", systemImage: "plus")
            }
            .chromeToolbarButton()
            .disabled(store.selectedWorkspace == nil)

            Button {
                store.chooseWorkspaceDirectory()
            } label: {
                Image(systemName: "folder.badge.plus")
                    .frame(width: 24, height: 24)
            }
            .chromeToolbarButton()
            .help("新建工作空间")
        }
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .frame(height: 48)
        .background(WindowChromeConfigurator())
    }
}

private struct WorkspaceTopBarInfo: View {
    @ObservedObject var workspace: Workspace

    var body: some View {
        HStack(spacing: 8) {
            Text(workspace.monogram)
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 27, height: 27)
                .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 7))

            Text(workspace.name)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(height: 28)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("当前项目：\(workspace.name)")
    }
}

private struct MacTrafficLightControls: View {
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            TrafficLightButton(
                color: Color(red: 1.000, green: 0.373, blue: 0.337),
                symbol: "xmark",
                title: "关闭窗口"
            ) {
                activeWindow?.performClose(nil)
            }

            TrafficLightButton(
                color: Color(red: 1.000, green: 0.741, blue: 0.180),
                symbol: "minus",
                title: "最小化窗口"
            ) {
                activeWindow?.performMiniaturize(nil)
            }

            TrafficLightButton(
                color: Color(red: 0.157, green: 0.784, blue: 0.251),
                symbol: "arrow.up.left.and.arrow.down.right",
                title: "进入或退出全屏"
            ) {
                activeWindow?.toggleFullScreen(nil)
            }
        }
        .environment(\.trafficLightsHovered, isHovering)
        .onHover { isHovering = $0 }
        .frame(height: 28)
    }

    private var activeWindow: NSWindow? {
        NSApp.keyWindow ?? NSApp.mainWindow
    }
}

private struct TrafficLightsHoveredKey: EnvironmentKey {
    static let defaultValue = false
}

private extension EnvironmentValues {
    var trafficLightsHovered: Bool {
        get { self[TrafficLightsHoveredKey.self] }
        set { self[TrafficLightsHoveredKey.self] = newValue }
    }
}

private struct TrafficLightButton: View {
    @Environment(\.trafficLightsHovered) private var controlsHovered

    let color: Color
    let symbol: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .overlay {
                    Circle()
                        .strokeBorder(.black.opacity(0.16), lineWidth: 0.5)
                }
                .overlay {
                    if controlsHovered {
                        Image(systemName: symbol)
                            .font(.system(size: 6.5, weight: .black))
                            .foregroundStyle(.black.opacity(0.58))
                    }
                }
                .frame(width: 12, height: 12)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
    }
}

private struct WorkspaceTopBarCenter: View {
    @ObservedObject var workspace: Workspace
    @ObservedObject private var project: ProjectSession

    init(workspace: Workspace) {
        self.workspace = workspace
        self.project = workspace.project
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: workspace.contentMode == .project ? "chevron.left.forwardslash.chevron.right" : "terminal")
                .foregroundStyle(.secondary)
            Text(title)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.system(size: 11.5, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 11)
        .frame(height: 27)
        .background(AppChromePalette.control, in: RoundedRectangle(cornerRadius: 7))
    }

    private var title: String {
        if workspace.contentMode == .project {
            return project.selectedDocument?.relativePath ?? "项目浏览器"
        }
        return workspace.selectedTab?.title ?? "终端"
    }
}

struct WorkspaceToolRail: View {
    @EnvironmentObject private var store: TerminalStore

    var body: some View {
        VStack(spacing: 7) {
            if let workspace = store.selectedWorkspace {
                RailButton(
                    icon: "terminal",
                    title: "终端",
                    isSelected: workspace.contentMode == .terminal
                ) {
                    workspace.contentMode = .terminal
                }

                RailButton(
                    icon: "folder",
                    title: "项目",
                    isSelected: workspace.contentMode == .project
                        && workspace.project.sidebarSection == .files
                ) {
                    workspace.contentMode = .project
                    workspace.project.sidebarSection = .files
                    workspace.project.activate()
                }

                RailButton(
                    icon: "checkmark.circle",
                    title: "提交",
                    isSelected: workspace.contentMode == .project
                        && workspace.project.sidebarSection == .commit
                ) {
                    workspace.contentMode = .project
                    workspace.project.sidebarSection = .commit
                    workspace.project.activate()
                }

                Rectangle()
                    .fill(AppChromePalette.border)
                    .frame(width: 20, height: 1)
                    .padding(.vertical, 2)

                RailButton(icon: "plus", title: "新建终端") {
                    store.addTab(to: workspace)
                }

                RailButton(icon: "arrow.right.circle", title: "在 Finder 中显示") {
                    NSWorkspace.shared.activateFileViewerSelecting([workspace.directory])
                }
            }

            Spacer()

            RailButton(icon: "folder.badge.plus", title: "新建工作空间") {
                store.chooseWorkspaceDirectory()
            }
        }
        .frame(width: 34)
        .padding(.vertical, 4)
    }
}

private struct RailButton: View {
    let icon: String
    let title: String
    var isSelected = false
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .frame(width: 29, height: 29)
                .background(
                    isSelected
                        ? Color.accentColor.opacity(0.14)
                        : (hovered ? AppChromePalette.control : Color.clear),
                    in: RoundedRectangle(cornerRadius: 7)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help(title)
    }
}

struct AppStatusBar: View {
    @EnvironmentObject private var store: TerminalStore

    var body: some View {
        HStack(spacing: 8) {
            if let workspace = store.selectedWorkspace {
                WorkspaceStatusContent(workspace: workspace)
            } else {
                Image(systemName: "square.grid.2x2")
                Text("选择目录创建工作空间")
                Spacer()
            }
        }
        .font(.system(size: 10.5))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .frame(height: 28)
    }
}

private struct WorkspaceStatusContent: View {
    @ObservedObject var workspace: Workspace
    @ObservedObject private var project: ProjectSession
    @ObservedObject private var git: GitRepository

    init(workspace: Workspace) {
        self.workspace = workspace
        self.project = workspace.project
        self.git = workspace.project.git
    }

    var body: some View {
        Image(systemName: "folder")
        Text(workspace.directory.path)
            .lineLimit(1)
            .truncationMode(.middle)

        Spacer()

        if git.isRepository, !git.branch.isEmpty {
            Image(systemName: "arrow.triangle.branch")
            Text(git.branch)
        }

        if workspace.contentMode == .project, let document = project.selectedDocument {
            DocumentStatusContent(document: document)
        } else {
            Image(systemName: "terminal")
            Text("\(workspace.tabs.count) 个终端")
        }
    }
}

private struct DocumentStatusContent: View {
    @ObservedObject var document: EditorDocument

    var body: some View {
        Text("Ln \(document.cursorLine), Col \(document.cursorColumn)")
        Text("UTF-8")
    }
}

private extension View {
    func chromeToolbarButton() -> some View {
        buttonStyle(.plain)
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .frame(height: 27)
            .background(AppChromePalette.control, in: RoundedRectangle(cornerRadius: 7))
    }
}

struct ChromeSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppChromePalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(AppChromePalette.border, lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    func chromeSurface() -> some View {
        modifier(ChromeSurface())
    }
}

private struct WindowChromeConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { ConfiguratorView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class ConfiguratorView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.backgroundColor = NSColor(
                srgbRed: 0.157,
                green: 0.161,
                blue: 0.173,
                alpha: 1
            )
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
