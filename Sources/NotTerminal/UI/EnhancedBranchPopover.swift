import SwiftUI

struct EnhancedBranchPopover: View {
    @ObservedObject var git: GitRepository
    let referenceListHeight: CGFloat
    let dismiss: () -> Void
    let openCommit: () -> Void

    @State private var query = ""
    @State private var collapsedGroups: Set<String> = []
    @State private var collapsedSections: Set<String> = []
    @State private var hoveredReferenceID: String?
    @State private var dialog: BranchDialog?
    @State private var branchPendingDeletion: GitReference?
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchBar
            Divider()
            primaryActions
            Divider()
            branchActions
            Divider()
            referenceList
            if let message = git.message, !message.isEmpty {
                errorBanner(message)
            }
        }
        .frame(width: 360)
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
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                TextField("Search for branches and actions", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13.5))
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
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 5))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(Color.primary.opacity(0.17), lineWidth: 1)
            }

            Button {
                git.refreshBranches()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 27, height: 27)
            }
            .buttonStyle(BranchToolbarButtonStyle())
            .help("Refresh branches")
            .disabled(git.isBusy)

            Menu {
                Button("Fetch All Remotes") { git.fetch() }
                Button("Refresh Branches") { git.refreshBranches() }
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 27, height: 27)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Git options")
            .disabled(git.isBusy)
        }
        .padding(.horizontal, 8)
        .frame(height: 48)
        .background(Color.primary.opacity(0.018))
    }

    private var primaryActions: some View {
        VStack(spacing: 0) {
            if !normalizedQuery.isEmpty, actionMatches("Fetch", aliases: ["fetch"]) {
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
                actionRow("Commit…", icon: "smallcircle.filled.circle", shortcut: "⌘K") {
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
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
    }

    private var branchActions: some View {
        VStack(spacing: 0) {
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
        .padding(.vertical, 7)
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
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 21)
                Text(title)
                    .font(.system(size: 13.5))
                Spacer()
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.tertiary)
                }
                if let shortcut {
                    Text(shortcut)
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 9)
            .frame(height: 30)
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
                LazyVStack(alignment: .leading, spacing: 0) {
                    if normalizedQuery.isEmpty, !git.recentReferences.isEmpty {
                        sectionHeader("Recent", id: "recent")
                        if !collapsedSections.contains("recent") {
                            referenceTree(recentLocalReferences, idPrefix: "recent")
                            ForEach(recentNonLocalReferences) { referenceRow($0, level: 0) }
                        }
                    }

                    if normalizedQuery.isEmpty {
                        localReferenceSections
                        remoteReferenceSections
                        if !git.tagReferences.isEmpty {
                            sectionHeader("Tags", id: "tags")
                            if !collapsedSections.contains("tags") {
                                ForEach(git.tagReferences) { referenceRow($0, level: 0) }
                            }
                        }
                    } else {
                        sectionHeader("Search Results", id: "search")
                        if !collapsedSections.contains("search") {
                            ForEach(filteredReferences) { referenceRow($0, level: 0) }
                        }
                    }
                }
                .padding(.vertical, 9)
            }
            .frame(height: min(referenceListHeight, referenceContentHeight))
        }
    }

    @ViewBuilder
    private var localReferenceSections: some View {
        if !git.localReferences.isEmpty {
            sectionHeader("Local", id: "local")
            if !collapsedSections.contains("local") {
                referenceTree(git.localReferences, idPrefix: "local")
            }
        }
    }

    @ViewBuilder
    private var remoteReferenceSections: some View {
        let groups = groupedRemoteReferences
        if !groups.isEmpty {
            sectionHeader("Remote", id: "remote")
            if !collapsedSections.contains("remote") {
                ForEach(groups) { group in groupRow(group, icon: "folder") }
            }
        }
    }

    @ViewBuilder
    private func referenceTree(_ references: [GitReference], idPrefix: String) -> some View {
        ForEach(groupedBranchReferences(references, idPrefix: idPrefix)) { group in
            if group.title.isEmpty {
                ForEach(group.references) { referenceRow($0, level: 0) }
            } else {
                groupRow(group, icon: "folder")
            }
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
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 10)
                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text(group.title)
                        .font(.system(size: 13.5))
                    Spacer()
                }
                .padding(.leading, 34)
                .padding(.trailing, 13)
                .frame(height: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(BranchHoverButtonStyle())

            if !collapsedGroups.contains(group.id) {
                ForEach(group.references) { referenceRow($0, level: 1) }
            }
        }
    }

    private func referenceRow(_ reference: GitReference, level: Int) -> some View {
        ZStack {
            HStack(spacing: 7) {
                Image(systemName: referenceIcon(reference))
                    .font(.system(size: 13, weight: reference.isCurrent ? .semibold : .regular))
                    .foregroundStyle(referenceIconColor(reference))
                    .frame(width: 17)
                Text(referenceRowTitle(reference, grouped: level > 0))
                    .font(.system(size: 13.5))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 7)
                if let upstream = reference.upstreamShortName {
                    Text(upstream)
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.leading, level > 0 ? 68 : 49)
            .padding(.trailing, 13)
            .frame(height: 28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                hoveredReferenceID == reference.id
                    ? Color.primary.opacity(0.075)
                    : Color.clear
            )

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
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(reference.displayName)
        }
        .frame(maxWidth: .infinity)
        .disabled(git.isBusy)
        .onHover { isHovered in
            if isHovered {
                hoveredReferenceID = reference.id
            } else if hoveredReferenceID == reference.id {
                hoveredReferenceID = nil
            }
        }
    }

    private func sectionHeader(_ title: String, id: String) -> some View {
        Button {
            if collapsedSections.contains(id) {
                collapsedSections.remove(id)
            } else {
                collapsedSections.insert(id)
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: collapsedSections.contains(id) ? "chevron.right" : "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .frame(width: 10)
                Text(title)
                Spacer()
            }
            .font(.system(size: 13.5, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .frame(height: 29)
            .contentShape(Rectangle())
        }
        .buttonStyle(BranchHoverButtonStyle(cornerRadius: 0))
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

    private var referenceContentHeight: CGFloat {
        let sectionHeight: CGFloat = 29
        let itemHeight: CGFloat = 28
        let verticalPadding: CGFloat = 18

        if !normalizedQuery.isEmpty {
            let items = collapsedSections.contains("search") ? 0 : filteredReferences.count
            return verticalPadding + sectionHeight + CGFloat(items) * itemHeight
        }

        var sectionCount = 0
        var itemCount = 0
        if !git.recentReferences.isEmpty {
            sectionCount += 1
            if !collapsedSections.contains("recent") {
                itemCount += treeItemCount(recentLocalReferences, idPrefix: "recent")
                itemCount += recentNonLocalReferences.count
            }
        }
        if !git.localReferences.isEmpty {
            sectionCount += 1
            if !collapsedSections.contains("local") {
                itemCount += treeItemCount(git.localReferences, idPrefix: "local")
            }
        }
        if !git.remoteReferences.isEmpty {
            sectionCount += 1
            if !collapsedSections.contains("remote") {
                itemCount += groupedRemoteReferences.reduce(0) { count, group in
                    count + 1 + (collapsedGroups.contains(group.id) ? 0 : group.references.count)
                }
            }
        }
        if !git.tagReferences.isEmpty {
            sectionCount += 1
            if !collapsedSections.contains("tags") { itemCount += git.tagReferences.count }
        }
        return verticalPadding
            + CGFloat(sectionCount) * sectionHeight
            + CGFloat(itemCount) * itemHeight
    }

    private func treeItemCount(_ references: [GitReference], idPrefix: String) -> Int {
        groupedBranchReferences(references, idPrefix: idPrefix).reduce(0) { count, group in
            if group.title.isEmpty { return count + group.references.count }
            return count + 1 + (collapsedGroups.contains(group.id) ? 0 : group.references.count)
        }
    }

    private func groupedBranchReferences(
        _ references: [GitReference],
        idPrefix: String
    ) -> [ReferenceGroup] {
        let grouped = Dictionary(grouping: references) { reference -> String in
            let components = reference.shortName.split(separator: "/")
            return components.count > 1 ? components.dropLast().joined(separator: "/") : ""
        }
        return grouped.map {
            ReferenceGroup(id: "\(idPrefix):\($0.key)", title: $0.key, references: $0.value)
        }
            .sorted { lhs, rhs in
                if lhs.title.isEmpty != rhs.title.isEmpty { return lhs.title.isEmpty }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
    }

    private var recentLocalReferences: [GitReference] {
        git.recentReferences.filter { $0.kind == .local }
    }

    private var recentNonLocalReferences: [GitReference] {
        git.recentReferences.filter { $0.kind != .local }
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
        if reference.isCurrent { return "tag.fill" }
        switch reference.kind {
        case .local: return "point.3.connected.trianglepath.dotted"
        case .remote: return "star.fill"
        case .tag: return "tag"
        }
    }

    private func referenceIconColor(_ reference: GitReference) -> Color {
        if reference.isCurrent || reference.kind == .remote {
            return Color(red: 0.96, green: 0.72, blue: 0.25)
        }
        return Color.secondary
    }

    private func referenceRowTitle(_ reference: GitReference, grouped: Bool) -> String {
        guard grouped, reference.shortName.contains("/") else {
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
    let cornerRadius: CGFloat
    @State private var hovered = false

    init(cornerRadius: CGFloat = 5) {
        self.cornerRadius = cornerRadius
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed
                    ? Color.primary.opacity(0.10)
                    : (hovered ? Color.primary.opacity(0.06) : Color.clear),
                in: RoundedRectangle(cornerRadius: cornerRadius)
            )
            .onHover { hovered = $0 }
    }
}

private struct BranchToolbarButtonStyle: ButtonStyle {
    @State private var hovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed
                    ? Color.primary.opacity(0.12)
                    : (hovered ? Color.primary.opacity(0.07) : Color.clear),
                in: RoundedRectangle(cornerRadius: 5)
            )
            .onHover { hovered = $0 }
    }
}
