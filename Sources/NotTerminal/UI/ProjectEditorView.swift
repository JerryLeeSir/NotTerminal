import AppKit
import SwiftUI

struct ProjectEditorView: View {
    @ObservedObject var workspace: Workspace
    @ObservedObject private var project: ProjectSession

    init(workspace: Workspace) {
        self.workspace = workspace
        self.project = workspace.project
    }

    var body: some View {
        VStack(spacing: 0) {
            EditorDocumentTabs(project: project)
            Divider()

            if let document = project.selectedDocument {
                EditorDocumentView(document: document)
                    .id(document.id)
            } else {
                ProjectEditorEmptyState(workspace: workspace)
            }
        }
        .background(EditorColors.background)
        .alert(
            "无法打开文件",
            isPresented: Binding(
                get: { project.alertMessage != nil },
                set: { if !$0 { project.alertMessage = nil } }
            )
        ) {
            Button("好", role: .cancel) { project.alertMessage = nil }
        } message: {
            Text(project.alertMessage ?? "")
        }
    }
}

private struct EditorDocumentTabs: View {
    @ObservedObject var project: ProjectSession

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(project.documents) { document in
                    EditorDocumentTab(
                        document: document,
                        isSelected: project.selectedDocumentID == document.id,
                        select: { project.select(document) },
                        close: { project.close(document) }
                    )
                }
            }
        }
        .frame(height: 38)
        .background(EditorColors.tabBar)
    }
}

private struct EditorDocumentTab: View {
    @ObservedObject var document: EditorDocument
    let isSelected: Bool
    let select: () -> Void
    let close: () -> Void
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: fileIcon)
                .font(.system(size: 11))
                .foregroundStyle(fileColor)
            Text(document.displayName)
                .font(.system(size: 11.5, weight: isSelected ? .medium : .regular))
                .lineLimit(1)
            if document.isDirty {
                Circle().fill(Color.secondary).frame(width: 6, height: 6)
            }
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .frame(width: 15, height: 15)
            }
            .buttonStyle(.plain)
            .opacity(hovered || isSelected ? 1 : 0)
        }
        .padding(.horizontal, 11)
        .frame(height: 38)
        .background(isSelected ? EditorColors.background : (hovered ? Color.primary.opacity(0.04) : Color.clear))
        .overlay(alignment: .bottom) {
            if isSelected { Rectangle().fill(Color.accentColor).frame(height: 2) }
        }
        .overlay(alignment: .trailing) { Divider() }
        .contentShape(Rectangle())
        .onTapGesture(perform: select)
        .onHover { hovered = $0 }
    }

    private var fileIcon: String {
        switch document.url.pathExtension.lowercased() {
        case "swift": "swift"
        case "dart": "diamond.fill"
        case "md", "markdown": "text.document"
        case "json", "yaml", "yml", "toml": "curlybraces"
        case "sh", "bash", "zsh": "terminal"
        default: "doc"
        }
    }

    private var fileColor: Color {
        switch document.url.pathExtension.lowercased() {
        case "swift": .orange
        case "dart": .cyan
        case "md", "markdown": .blue
        case "json", "yaml", "yml", "toml": .yellow
        default: .secondary
        }
    }
}

private struct EditorDocumentView: View {
    @ObservedObject var document: EditorDocument

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Text(document.relativePath)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button {
                    document.save()
                } label: {
                    Label(document.isDirty ? "保存" : "已保存", systemImage: document.isDirty ? "square.and.arrow.down" : "checkmark")
                        .font(.system(size: 10.5, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(document.isDirty ? Color.accentColor : Color.secondary)
                .disabled(!document.isDirty)
                .keyboardShortcut("s", modifiers: .command)
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(EditorColors.breadcrumb)

            Divider()

            CodeTextEditor(document: document)

            Divider()

            HStack(spacing: 16) {
                if let error = document.saveError {
                    Text(error).foregroundStyle(.red).lineLimit(1)
                }
                Spacer()
                Text("Ln \(document.cursorLine), Col \(document.cursorColumn)")
                Text("空格: 4")
                Text("UTF-8")
                Text(document.url.pathExtension.uppercased())
            }
            .font(.system(size: 10.5))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .frame(height: 24)
            .background(EditorColors.tabBar)
        }
    }
}

private struct ProjectEditorEmptyState: View {
    @ObservedObject var workspace: Workspace

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(.tertiary)
            Text(workspace.name)
                .font(.system(size: 18, weight: .semibold))
            Text("从左侧项目树选择文件开始编辑")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private enum EditorColors {
    static let background = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.110, green: 0.114, blue: 0.122, alpha: 1)
            : NSColor.white
    })
    static let tabBar = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.095, green: 0.099, blue: 0.107, alpha: 1)
            : NSColor(srgbRed: 0.969, green: 0.973, blue: 0.980, alpha: 1)
    })
    static let breadcrumb = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.110, green: 0.114, blue: 0.122, alpha: 1)
            : NSColor.white
    })
}

private struct CodeTextEditor: NSViewRepresentable {
    @ObservedObject var document: EditorDocument

    func makeCoordinator() -> Coordinator { Coordinator(document: document) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor(EditorColors.background)

        let textView = IDECodeTextView(frame: NSRect(x: 0, y: 0, width: 900, height: 700))
        textView.delegate = context.coordinator
        textView.string = document.text
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.font = BundledFontRegistry.editorFont(size: 13)
        textView.textColor = EditorCodePalette.current().text
        textView.insertionPointColor = .white
        textView.backgroundColor = EditorCodePalette.current().background
        textView.textContainerInset = NSSize(width: 4, height: 3)
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes = [
            .font: BundledFontRegistry.editorFont(size: 13),
            .paragraphStyle: paragraphStyle,
            .foregroundColor: EditorCodePalette.current().text,
            .ligature: 0
        ]
        applyTextStyle(to: textView)
        textView.applyEditorAppearance()

        scrollView.documentView = textView
        let ruler = LineNumberRulerView(textView: textView, scrollView: scrollView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        context.coordinator.textView = textView
        context.coordinator.ruler = ruler
        EditorSyntaxHighlighter.apply(to: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        if textView.string != document.text {
            let selection = textView.selectedRange()
            textView.string = document.text
            textView.setSelectedRange(NSRange(location: min(selection.location, (document.text as NSString).length), length: 0))
            applyTextStyle(to: textView)
            context.coordinator.ruler?.needsDisplay = true
            EditorSyntaxHighlighter.apply(to: textView)
        }
    }

    private func applyTextStyle(to textView: NSTextView) {
        guard let storage = textView.textStorage, storage.length > 0 else { return }
        storage.addAttributes(
            [
                .font: BundledFontRegistry.editorFont(size: 13),
                .paragraphStyle: paragraphStyle,
                .foregroundColor: EditorCodePalette.current(for: textView.effectiveAppearance).text,
                .ligature: 0
            ],
            range: NSRange(location: 0, length: storage.length)
        )
    }

    private var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.tabStops = []
        style.defaultTabInterval = 32
        style.lineHeightMultiple = 1.2
        return style
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        let document: EditorDocument
        weak var textView: NSTextView?
        weak var ruler: LineNumberRulerView?

        init(document: EditorDocument) { self.document = document }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            document.text = textView.string
            updateCursor(textView)
            ruler?.needsDisplay = true
            EditorSyntaxHighlighter.apply(to: textView)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView else { return }
            updateCursor(textView)
            ruler?.needsDisplay = true
        }

        private func updateCursor(_ textView: NSTextView) {
            let location = min(textView.selectedRange().location, (textView.string as NSString).length)
            let prefix = (textView.string as NSString).substring(to: location)
            let lines = prefix.components(separatedBy: "\n")
            document.cursorLine = lines.count
            document.cursorColumn = (lines.last?.utf16.count ?? 0) + 1
        }

    }
}

private final class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?

    init(textView: NSTextView, scrollView: NSScrollView) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 54
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(redraw),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func redraw() { needsDisplay = true }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let scrollView else { return }

        let palette = EditorCodePalette.current(for: effectiveAppearance)
        palette.background.setFill()
        bounds.fill()

        let origin = convert(NSZeroPoint, from: textView)
        let visibleRect = scrollView.contentView.bounds
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let source = textView.string as NSString
        var lineNumber = 1
        if glyphRange.location > 0 {
            lineNumber += source.substring(to: layoutManager.characterIndexForGlyph(at: glyphRange.location))
                .reduce(0) { $1 == "\n" ? $0 + 1 : $0 }
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: BundledFontRegistry.editorFont(size: 12),
            .foregroundColor: palette.lineNumber
        ]
        var glyphIndex = glyphRange.location
        while glyphIndex < NSMaxRange(glyphRange) {
            var lineGlyphRange = NSRange()
            let lineRect = layoutManager.lineFragmentRect(
                forGlyphAt: glyphIndex,
                effectiveRange: &lineGlyphRange,
                withoutAdditionalLayout: true
            )
            let number = "\(lineNumber)" as NSString
            let size = number.size(withAttributes: attributes)
            number.draw(
                at: NSPoint(
                    x: ruleThickness - size.width - 8,
                    y: origin.y + textView.textContainerOrigin.y + lineRect.minY + 1
                ),
                withAttributes: attributes
            )
            glyphIndex = NSMaxRange(lineGlyphRange)
            lineNumber += 1
        }

        palette.divider.setFill()
        NSRect(x: ruleThickness - 1, y: 0, width: 1, height: bounds.height).fill()
    }
}
