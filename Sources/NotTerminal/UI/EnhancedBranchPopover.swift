import SwiftUI

struct EnhancedBranchPopover: View {
    @ObservedObject var git: GitRepository
    let dismiss: () -> Void
    let openCommit: () -> Void

    @State private var query = ""
    @State private var collapsedGroups: Set<String> = []
    @State private var dialog: BranchDialog?
    @State private var branchPendingDeletion: GitReference?
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchBar
            Divider()
            actionList
            Divider()
            referenceList
            if let message = git.message, !message.isEmpty {
                errorBanner(message)
            }
        }
        .frame(width: 375)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            searchFocused = true
            git.refresh()
        }
        .sheet(item: $dialog) { dialog in
            BranchOperationDialog(dialog: dialog, git: git)
        }
        .alert(
            "Delete branch?",
            isPresented: Binding(
                get: { branchPendingDeletion != nil },
                set: { if !$0 { branchPendingDeletion = nil } }
            ),
            presenting: branchPendingDeletion
        ) { reference in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                git.deleteBranch(reference) { succeeded in
                    if succeeded { dismiss() }
                }
            }
        } message: { reference in
            Text("Delete the local branch “\(reference.shortName)”? Git will refuse if it contains unmerged work.")
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            TextField("Search branches and actions", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .focused($searchFocused)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            if git.isBusy { ProgressView().controlSize(.mini) }
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(Color.primary.opacity(0.035))
    }

    private var actionList: some View {
        VStack(spacing: 1) {
            if actionMatches("Fetch", aliases: ["fetch"]) {
                actionRow("Fetch", icon: "arrow.down.to.line") {
                    git.fetch { succeeded in if succeeded { dismiss() } }
                }
            }
            if actionMatches("Update Project", aliases: ["update", "pull"]) {
                actionRow("Update Project…", icon: "arrow.down.left", detail: trackingDetail) {
                    git.updateCurrentBranch { succeeded in if succeeded { dismiss() } }
                }
                .disabled(git.currentReference == nil || git.isBusy)
            }
            if actionMatches("Commit", aliases: ["commit"]) {
                actionRow("Commit…", icon: "checkmark.circle", shortcut: "⌘K") {
                    dismiss()
                    openCommit()
                }
            }
            if actionMatches("Push", aliases: ["push"]) {
                actionRow("Push…", icon: "arrow.up.right", shortcut: "⇧⌘K") {
                    guard let current = git.currentReference else { return }
                    git.push(current) { succeeded in if succeeded { dismiss() } }
                }
                .disabled(git.currentReference == nil || git.isBusy)
            }
            if actionMatches("New Branch", aliases: ["new branch"]) {
                actionRow("New Branch…", icon: "plus", shortcut: "⌥⌘N") {
                    guard let current = git.currentReference else { return }
                    dialog = .newBranch(current)
                }
                .disabled(git.currentReference == nil || git.isBusy)
            }
            if actionMatches("Checkout Tag or Revision", aliases: ["checkout", "revision", "tag"]) {
                actionRow("Checkout Tag or Revision…", icon: "number") {
                    dialog = .checkoutRevision
                }
                .disabled(git.isBusy)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func actionRow(
        _ title: String,
        icon: String,
        detail: String? = nil,
        shortcut: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .frame(width: 17)
                Text(title)
                    .font(.system(size: 12.5))
                Spacer()
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                }
                if let shortcut {
                    Text(shortcut)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 7)
            .frame(height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(BranchHoverButtonStyle())
    }

    @ViewBuilder
    private var referenceList: some View {
        if !git.isRepository {
            emptyState("The current directory is not a Git repository.")
        } else if filteredReferences.isEmpty {
            emptyState("No matching branches or tags.")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    if normalizedQuery.isEmpty, !git.recentReferences.isEmpty {
                        sectionHeader("Recent", icon: "clock")
                        ForEach(git.recentReferences) { referenceRow($0, indented: false) }
                    }

                    if normalizedQuery.isEmpty {
                        localReferenceSections
                        remoteReferenceSections
                        if !git.tagReferences.isEmpty {
                            sectionHeader("Tags", icon: "tag")
                            ForEach(git.tagReferences) { referenceRow($0, indented: true) }
                        }
                    } else {
                        sectionHeader("Search Results", icon: "magnifyingglass")
                        ForEach(filteredReferences) { referenceRow($0, indented: false) }
                    }
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 6)
            }
            .frame(height: 280)
        }
    }

    @ViewBuilder
    private var localReferenceSections: some View {
        let groups = groupedLocalReferences
        if !groups.isEmpty {
            sectionHeader("Local", icon: "point.3.connected.trianglepath.dotted")
            ForEach(groups) { group in
                if group.title.isEmpty {
                    ForEach(group.references) { referenceRow($0, indented: true) }
                } else {
                    groupRow(group, icon: "folder")
                }
            }
        }
    }

    @ViewBuilder
    private var remoteReferenceSections: some View {
        let groups = groupedRemoteReferences
        if !groups.isEmpty {
            sectionHeader("Remote", icon: "cloud")
            ForEach(groups) { group in groupRow(group, icon: "externaldrive") }
        }
    }

    private func groupRow(_ group: ReferenceGroup, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Button {
                if collapsedGroups.contains(group.id) {
                    collapsedGroups.remove(group.id)
                } else {
                    collapsedGroups.insert(group.id)
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: collapsedGroups.contains(group.id) ? "chevron.right" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .frame(width: 10)
                    Image(systemName: icon)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                    Text(group.title)
                        .font(.system(size: 11.5, weight: .medium))
                    Spacer()
                    Text("\(group.references.count)")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 7)
                .frame(height: 25)
                .contentShape(Rectangle())
            }
            .buttonStyle(BranchHoverButtonStyle())

            if !collapsedGroups.contains(group.id) {
                ForEach(group.references) { referenceRow($0, indented: true) }
            }
        }
    }

    private func referenceRow(_ reference: GitReference, indented: Bool) -> some View {
        Menu {
            Button("New Branch from '\(reference.shortName)'…") {
                dialog = .newBranch(reference)
            }
            Button("Show Diff with Working Tree") {
                git.compareWithWorkingTree(reference) { succeeded in
                    if succeeded { dismiss() }
                }
            }
            if let current = git.currentReference, current.id != reference.id {
                Button("Compare with Current Branch") {
                    git.compare(reference, with: current) { succeeded in
                        if succeeded { dismiss() }
                    }
                }
            }
            if !reference.isCurrent {
                Divider()
                Button("Checkout") {
                    git.checkout(reference) { succeeded in if succeeded { dismiss() } }
                }
            }
            if reference.kind == .local {
                Divider()
                Button("Update") {
                    git.updateCurrentBranch { succeeded in if succeeded { dismiss() } }
                }
                .disabled(!reference.isCurrent)
                Button("Push…") {
                    git.push(reference) { succeeded in if succeeded { dismiss() } }
                }
                if !reference.isCurrent {
                    Button("Delete Branch", role: .destructive) {
                        branchPendingDeletion = reference
                    }
                }
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: referenceIcon(reference))
                    .font(.system(size: 10.5, weight: reference.isCurrent ? .semibold : .regular))
                    .foregroundStyle(reference.isCurrent ? Color.accentColor : Color.secondary)
                    .frame(width: 15)
                Text(referenceRowTitle(reference, indented: indented))
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 7)
                if let upstream = reference.upstreamShortName {
                    Text(upstream)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else if reference.kind == .remote, let remote = reference.remoteName {
                    Text(remote)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.leading, indented ? 20 : 7)
            .padding(.trailing, 7)
            .frame(height: 27)
            .background(
                reference.isCurrent ? Color.accentColor.opacity(0.12) : Color.clear,
                in: RoundedRectangle(cornerRadius: 5)
            )
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .disabled(git.isBusy)
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).frame(width: 13)
            Text(title)
            Spacer()
        }
        .font(.system(size: 10.5, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 7)
        .padding(.top, 7)
        .padding(.bottom, 2)
    }

    private func emptyState(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11.5))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 120)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.system(size: 10.5))
                .foregroundStyle(.red)
                .lineLimit(3)
            Spacer(minLength: 4)
            Button { git.clearMessage() } label: { Image(systemName: "xmark") }
                .buttonStyle(.plain)
        }
        .padding(9)
        .background(Color.red.opacity(0.08))
    }

    private var filteredReferences: [GitReference] {
        guard !normalizedQuery.isEmpty else { return git.references }
        return git.references.filter {
            $0.shortName.localizedCaseInsensitiveContains(normalizedQuery)
                || ($0.upstreamShortName?.localizedCaseInsensitiveContains(normalizedQuery) ?? false)
        }
    }

    private var groupedLocalReferences: [ReferenceGroup] {
        let grouped = Dictionary(grouping: git.localReferences) { reference -> String in
            let components = reference.shortName.split(separator: "/")
            return components.count > 1 ? components.dropLast().joined(separator: "/") : ""
        }
        return grouped.map { ReferenceGroup(id: "local:\($0.key)", title: $0.key, references: $0.value) }
            .sorted { lhs, rhs in
                if lhs.title.isEmpty != rhs.title.isEmpty { return lhs.title.isEmpty }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
    }

    private var groupedRemoteReferences: [ReferenceGroup] {
        let grouped = Dictionary(grouping: git.remoteReferences) { $0.remoteName ?? "Remote" }
        return grouped.map { ReferenceGroup(id: "remote:\($0.key)", title: $0.key, references: $0.value) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func actionMatches(_ title: String, aliases: [String]) -> Bool {
        guard !normalizedQuery.isEmpty else { return true }
        return ([title] + aliases).contains {
            $0.localizedCaseInsensitiveContains(normalizedQuery)
        }
    }

    private var trackingDetail: String {
        var values: [String] = []
        if git.ahead > 0 { values.append("↑\(git.ahead)") }
        if git.behind > 0 { values.append("↓\(git.behind)") }
        return values.joined(separator: " ")
    }

    private func referenceIcon(_ reference: GitReference) -> String {
        if reference.isCurrent { return "checkmark" }
        switch reference.kind {
        case .local: return "point.3.connected.trianglepath.dotted"
        case .remote: return "cloud"
        case .tag: return "tag"
        }
    }

    private func referenceRowTitle(_ reference: GitReference, indented: Bool) -> String {
        guard indented, reference.kind == .local, reference.shortName.contains("/") else {
            return reference.displayName
        }
        return reference.shortName.split(separator: "/").last.map(String.init)
            ?? reference.displayName
    }
}

private struct ReferenceGroup: Identifiable {
    let id: String
    let title: String
    let references: [GitReference]
}

private enum BranchDialog: Identifiable {
    case newBranch(GitReference)
    case checkoutRevision

    var id: String {
        switch self {
        case .newBranch(let reference): return "new:\(reference.id)"
        case .checkoutRevision: return "revision"
        }
    }
}

private struct BranchOperationDialog: View {
    @Environment(\.dismiss) private var dismiss
    let dialog: BranchDialog
    @ObservedObject var git: GitRepository

    @State private var value = ""
    @State private var checkoutAfterCreation = true
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.system(size: 16, weight: .semibold))
            Text(detail)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $value)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(submit)
            if case .newBranch = dialog {
                Toggle("Checkout branch after creation", isOn: $checkoutAfterCreation)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(actionTitle, action: submit)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedValue.isEmpty || git.isBusy)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear { focused = true }
    }

    private var title: String {
        switch dialog {
        case .newBranch: return "New Branch"
        case .checkoutRevision: return "Checkout Tag or Revision"
        }
    }

    private var detail: String {
        switch dialog {
        case .newBranch(let reference): return "Create from '\(reference.shortName)'."
        case .checkoutRevision: return "Enter a tag, branch, or commit hash. Checkout will enter detached HEAD."
        }
    }

    private var placeholder: String {
        switch dialog {
        case .newBranch: return "Branch name"
        case .checkoutRevision: return "Tag, branch, or commit hash"
        }
    }

    private var actionTitle: String {
        switch dialog {
        case .newBranch: return "Create"
        case .checkoutRevision: return "Checkout"
        }
    }

    private var trimmedValue: String { value.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func submit() {
        guard !trimmedValue.isEmpty else { return }
        switch dialog {
        case .newBranch(let reference):
            git.createBranch(
                named: trimmedValue,
                from: reference,
                checkout: checkoutAfterCreation
            ) { succeeded in if succeeded { dismiss() } }
        case .checkoutRevision:
            git.checkoutRevision(trimmedValue) { succeeded in if succeeded { dismiss() } }
        }
    }
}

struct GitComparisonSheet: View {
    let comparison: GitComparison
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundStyle(Color.accentColor)
                Text(comparison.title).font(.system(size: 13, weight: .semibold))
                Spacer()
                Button("Done", action: dismiss).keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 14)
            .frame(height: 42)
            Divider()
            ScrollView([.horizontal, .vertical]) {
                Text(comparison.patch)
                    .font(.system(size: 11.5, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(minWidth: 760, minHeight: 500)
    }
}

private struct BranchHoverButtonStyle: ButtonStyle {
    @State private var hovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed
                    ? Color.primary.opacity(0.10)
                    : (hovered ? Color.primary.opacity(0.06) : Color.clear),
                in: RoundedRectangle(cornerRadius: 5)
            )
            .onHover { hovered = $0 }
    }
}
