import Combine
import Foundation

enum WorkspaceContentMode {
    case terminal
    case project
}

enum ProjectMonogram {
    static func make(from name: String) -> String {
        let characters = Array(name)
        var result: [Character] = []
        var startsWord = true

        for index in characters.indices {
            let character = characters[index]
            guard character.isLetter || character.isNumber else {
                startsWord = true
                continue
            }

            let previous = index > characters.startIndex ? characters[index - 1] : nil
            let next = index < characters.index(before: characters.endIndex)
                ? characters[index + 1]
                : nil
            let beginsCamelCaseWord = character.isUppercase
                && ((previous?.isLowercase ?? false)
                    || ((previous?.isUppercase ?? false) && (next?.isLowercase ?? false)))

            if startsWord || beginsCamelCaseWord {
                result.append(character)
                if result.count == 2 { break }
            }
            startsWord = false
        }

        return result.isEmpty ? "?" : String(result).uppercased()
    }
}

@MainActor
final class Workspace: ObservableObject, Identifiable {
    let id = UUID()
    let directory: URL

    @Published var tabs: [TerminalTab] = []
    @Published var selectedTabID: UUID?
    @Published var contentMode: WorkspaceContentMode = .terminal

    let project: ProjectSession

    init(directory: URL) {
        let directory = directory.standardizedFileURL
        self.directory = directory
        self.project = ProjectSession(directory: directory)
    }

    var name: String {
        directory.lastPathComponent
    }

    var monogram: String {
        ProjectMonogram.make(from: name)
    }

    var selectedTab: TerminalTab? {
        tabs.first { $0.id == selectedTabID }
    }
}
