import SwiftUI

@main
struct NotTerminalApp: App {
    @StateObject private var store = TerminalStore()

    init() {
        BundledFontRegistry.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
        .defaultSize(width: 1100, height: 700)
    }
}
