import Combine
import Foundation
import GhosttyTerminal

@MainActor
final class TerminalTab: ObservableObject, Identifiable {
    let id = UUID()
    let state: TerminalViewState

    @Published var title: String = "Terminal"
    @Published var workingDirectory: String?

    private var cancellables = Set<AnyCancellable>()

    init(
        controller: TerminalController,
        workingDirectory: String? = nil,
        onClose: @escaping (TerminalTab) -> Void
    ) {
        let defaultDir = FileManager.default.homeDirectoryForCurrentUser.path
        let dir = workingDirectory ?? defaultDir
        self.state = TerminalViewState(controller: controller)
        self.workingDirectory = dir

        self.state.configuration = TerminalSurfaceOptions(
            backend: .exec,
            fontSize: 13,
            workingDirectory: dir
        )

        self.state.$title
            .receive(on: DispatchQueue.main)
            .sink { [weak self] title in
                guard let self else { return }
                self.title = title.isEmpty ? "Terminal" : title
            }
            .store(in: &cancellables)

        self.state.$workingDirectory
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] dir in
                self?.workingDirectory = dir
            }
            .store(in: &cancellables)

        self.state.onClose = { [weak self] _ in
            guard let self else { return }
            onClose(self)
        }
    }
}