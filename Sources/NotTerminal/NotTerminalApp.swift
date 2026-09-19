import SwiftUI

@main
struct NotTerminalApp: App {
    @StateObject private var store = TerminalStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
        .defaultSize(width: 1100, height: 700)
    }
}