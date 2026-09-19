import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: TerminalStore

    var body: some View {
        HSplitView {
            Sidebar()
                .frame(minWidth: 200, idealWidth: 240, maxWidth: 360)

            Group {
                if let tab = store.selectedTab {
                    VStack(spacing: 0) {
                        TabStrip()
                        Divider()
                        TerminalHostView(tab: tab)
                    }
                } else {
                    EmptyStateView()
                }
            }
            .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            if store.tabs.isEmpty {
                store.addTab()
            }
        }
    }
}

struct EmptyStateView: View {
    @EnvironmentObject private var store: TerminalStore

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("没有打开的终端")
                .font(.headline)
            Button("新建终端") {
                store.addTab()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
