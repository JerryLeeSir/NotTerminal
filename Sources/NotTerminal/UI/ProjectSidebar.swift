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
    @State private var isPresented = false
    @State private var hovered = false

    init(project: ProjectSession) {
        self.git = project.git
    }

    var body: some View {
        Button {
            isPresented = true
            git.refreshBranches()
        } label: {
            HStack(spacing: 4) {
                GitBranchGlyph()
                Text(git.branch.isEmpty ? "分支" : git.branch)
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
        .help("切换 Git 分支")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            ProjectBranchPopover(git: git) {
                isPresented = false
            }
        }
    }
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

private struct ProjectBranchPopover: View {
    @ObservedObject private var git: GitRepository
    let dismiss: () -> Void

    @State private var query = ""
    @FocusState private var searchFocused: Bool

    init(git: GitRepository, dismiss: @escaping () -> Void) {
        self.git = git
        self.dismiss = dismiss
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("搜索分支", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($searchFocused)
            }
            .padding(.horizontal, 9)
            .frame(height: 30)

            Divider()

            content
        }
        .frame(width: 260)
        .onAppear {
            searchFocused = true
            git.refresh()
        }
    }

    @ViewBuilder
    private var content: some View {
        if !git.isRepository {
            Text("当前目录不是 Git 仓库")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .padding(12)
        } else if filteredLocal.isEmpty && filteredRemote.isEmpty {
            Text("没有匹配的分支")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .padding(12)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    if !filteredLocal.isEmpty {
                        sectionHeader("本地")
                        ForEach(filteredLocal) { branch in
                            BranchRow(branch: branch, isCurrent: branch.name == git.branch) {
                                checkout(branch)
                            }
                        }
                    }

                    if !filteredRemote.isEmpty {
                        sectionHeader("远程")
                        ForEach(filteredRemote) { branch in
                            BranchRow(branch: branch, isCurrent: false) {
                                checkout(branch)
                            }
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
            }
            .frame(height: 240)
        }
    }

    private var filteredLocal: [GitBranch] {
        git.localBranches.filter(matches)
    }

    private var filteredRemote: [GitBranch] {
        git.remoteBranches.filter(matches)
    }

    private func matches(_ branch: GitBranch) -> Bool {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return true }
        return branch.name.localizedCaseInsensitiveContains(normalized)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.top, 6)
            .padding(.bottom, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func checkout(_ branch: GitBranch) {
        git.checkout(branch)
        dismiss()
    }
}

private struct BranchRow: View {
    let branch: GitBranch
    let isCurrent: Bool
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 10, weight: isCurrent ? .bold : .regular))
                    .foregroundStyle(isCurrent ? Color.accentColor : Color.secondary)
                    .frame(width: 14)

                Text(branch.displayName)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 4)

                if branch.isRemote {
                    Text(branch.remoteName)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 7)
            .frame(height: 26)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isCurrent
                    ? Color.accentColor.opacity(0.14)
                    : (hovered ? Color.primary.opacity(0.06) : Color.clear),
                in: RoundedRectangle(cornerRadius: 5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }

    private var iconName: String {
        if isCurrent { return "checkmark" }
        return branch.isRemote ? "cloud" : "arrow.triangle.branch"
    }
}
