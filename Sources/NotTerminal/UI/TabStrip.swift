import GhosttyTerminal
import SwiftUI

struct TerminalHostView: View {
    @ObservedObject var tab: TerminalTab
    @FocusState private var terminalFocused: Bool

    var body: some View {
        TerminalSurfaceView(context: tab.state)
            .terminalFocused($terminalFocused)
            .onAppear {
                terminalFocused = true
            }
            .background(Color.black)
            .id("surface-\(tab.id)")
    }
}

struct TabStrip: View {
    @EnvironmentObject private var store: TerminalStore
    @State private var hoveredTabID: UUID?

    var body: some View {
        HStack(spacing: 6) {
            ForEach(store.tabs) { tab in
                TabStripItem(
                    tab: tab,
                    isSelected: tab.id == store.selectedTabID,
                    isHovered: hoveredTabID == tab.id
                )
                .onHover { hovering in
                    hoveredTabID = hovering ? tab.id : nil
                }
                .onTapGesture {
                    store.select(tab)
                }
            }

            Button {
                store.addTab()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("新建终端")

            Spacer(minLength: 0)
        }
        .padding(.leading, 10)
        .padding(.vertical, 6)
        .background(.bar)
    }
}

struct TabStripItem: View {
    @EnvironmentObject private var store: TerminalStore
    @ObservedObject var tab: TerminalTab
    let isSelected: Bool
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(tab.title)
                .lineLimit(1)
                .truncationMode(.middle)
                .font(.system(size: 12))
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)

            Button {
                store.close(tab: tab)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .frame(width: 14, height: 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .opacity(isHovered || isSelected ? 1 : 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .frame(maxWidth: 180)
        .background(
            isSelected ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear),
            in: RoundedRectangle(cornerRadius: 6)
        )
        .contentShape(RoundedRectangle(cornerRadius: 6))
    }
}