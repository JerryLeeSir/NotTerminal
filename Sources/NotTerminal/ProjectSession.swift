import AppKit
import Combine
import Foundation

enum ProjectSidebarSection: String, CaseIterable, Identifiable {
    case files
    case git

    var id: String { rawValue }
    var title: String { self == .files ? "项目" : "Git" }
    var icon: String { self == .files ? "folder" : "arrow.triangle.branch" }
}

@MainActor
final class ProjectSession: ObservableObject {
    let directory: URL
    let root: ProjectFileNode
    let git: GitRepository

    @Published var sidebarSection: ProjectSidebarSection = .files
    @Published var documents: [EditorDocument] = []
    @Published var selectedDocumentID: UUID?
    @Published var alertMessage: String?

    init(directory: URL) {
        self.directory = directory.standardizedFileURL
        self.root = ProjectFileNode(url: directory.standardizedFileURL, isDirectory: true)
        self.git = GitRepository(directory: directory.standardizedFileURL)
    }

    var selectedDocument: EditorDocument? {
        documents.first { $0.id == selectedDocumentID }
    }

    func activate() {
        root.loadChildren()
        git.refresh()
    }

    func open(_ url: URL) {
        let url = url.standardizedFileURL
        guard isInsideWorkspace(url) else {
            alertMessage = "无法打开工作空间之外的文件。"
            return
        }

        if let existing = documents.first(where: { $0.url == url }) {
            selectedDocumentID = existing.id
            return
        }

        do {
            let document = try EditorDocument(url: url, workspaceDirectory: directory)
            documents.append(document)
            selectedDocumentID = document.id
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func select(_ document: EditorDocument) {
        selectedDocumentID = document.id
    }

    func close(_ document: EditorDocument) {
        guard let index = documents.firstIndex(where: { $0.id == document.id }) else { return }
        documents.remove(at: index)

        if selectedDocumentID == document.id {
            selectedDocumentID = documents.indices.contains(index)
                ? documents[index].id
                : documents.last?.id
        }
    }

    func refreshFiles() {
        root.reload()
    }

    private func isInsideWorkspace(_ url: URL) -> Bool {
        let rootPath = directory.path.hasSuffix("/") ? directory.path : directory.path + "/"
        return url == directory || url.path.hasPrefix(rootPath)
    }
}

@MainActor
final class ProjectFileNode: ObservableObject, Identifiable {
    nonisolated let id: String
    let url: URL
    let isDirectory: Bool
    @Published private(set) var children: [ProjectFileNode]?
    @Published var isExpanded = false
    @Published private(set) var loadError: String?

    var name: String { url.lastPathComponent }

    init(url: URL, isDirectory: Bool) {
        self.url = url.standardizedFileURL
        self.id = url.standardizedFileURL.path
        self.isDirectory = isDirectory
    }

    func toggle() {
        guard isDirectory else { return }
        if children == nil { loadChildren() }
        isExpanded.toggle()
    }

    func reload() {
        let wasLoaded = children != nil
        children = nil
        loadError = nil
        if wasLoaded || isExpanded {
            loadChildren()
        }
    }

    func loadChildren() {
        guard isDirectory, children == nil else { return }
        do {
            let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey, .isHiddenKey]
            let urls = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: Array(keys),
                options: []
            )
            let excludedDirectories: Set<String> = [".git", ".build", "node_modules", "DerivedData"]
            children = urls.compactMap { childURL in
                let values = try? childURL.resourceValues(forKeys: keys)
                let isDirectory = values?.isDirectory == true
                if isDirectory && excludedDirectories.contains(childURL.lastPathComponent) {
                    return nil
                }
                return ProjectFileNode(url: childURL, isDirectory: isDirectory)
            }
            .sorted {
                if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        } catch {
            loadError = error.localizedDescription
            children = []
        }
    }
}

@MainActor
final class EditorDocument: ObservableObject, Identifiable {
    enum DocumentError: LocalizedError {
        case tooLarge
        case binary
        case unreadable

        var errorDescription: String? {
            switch self {
            case .tooLarge: "文件超过 5 MB，暂不支持在编辑器中打开。"
            case .binary: "这是二进制文件，无法作为文本编辑。"
            case .unreadable: "无法读取这个文件。"
            }
        }
    }

    let id = UUID()
    let url: URL
    let relativePath: String
    @Published var text: String
    @Published private(set) var savedText: String
    @Published var cursorLine = 1
    @Published var cursorColumn = 1
    @Published private(set) var saveError: String?

    var displayName: String { url.lastPathComponent }
    var isDirty: Bool { text != savedText }

    init(url: URL, workspaceDirectory: URL) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        if let size = attributes[.size] as? NSNumber, size.intValue > 5 * 1024 * 1024 {
            throw DocumentError.tooLarge
        }
        guard let data = FileManager.default.contents(atPath: url.path) else {
            throw DocumentError.unreadable
        }
        guard !data.prefix(8_192).contains(0) else { throw DocumentError.binary }
        guard let text = String(data: data, encoding: .utf8) else { throw DocumentError.binary }

        self.url = url
        let rootPath = workspaceDirectory.standardizedFileURL.path
        self.relativePath = String(url.path.dropFirst(min(url.path.count, rootPath.count + 1)))
        self.text = text
        self.savedText = text
    }

    func save() {
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            savedText = text
            saveError = nil
        } catch {
            saveError = error.localizedDescription
        }
    }
}
