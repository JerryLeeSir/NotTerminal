import Foundation

struct Project: Identifiable, Equatable {
    let url: URL

    var id: URL { url }
    var name: String { url.lastPathComponent }

    static func discover(from directory: URL) -> [Project] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return urls
            .compactMap { url -> URL? in
                guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else {
                    return nil
                }
                return url
            }
            .map(Project.init(url:))
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}