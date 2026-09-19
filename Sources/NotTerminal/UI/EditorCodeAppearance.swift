import AppKit

struct EditorCodePalette {
    let background: NSColor
    let text: NSColor
    let lineNumber: NSColor
    let currentLine: NSColor
    let selection: NSColor
    let guide: NSColor
    let activeGuide: NSColor
    let divider: NSColor
    let keyword: NSColor
    let number: NSColor
    let string: NSColor
    let comment: NSColor
    let callable: NSColor
    let property: NSColor
    let annotation: NSColor

    static func current(for appearance: NSAppearance? = NSApp.effectiveAppearance) -> Self {
        let dark = appearance?.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if dark {
            return Self(
                background: NSColor(srgbRed: 0.110, green: 0.114, blue: 0.122, alpha: 1),
                text: NSColor(srgbRed: 0.737, green: 0.745, blue: 0.769, alpha: 1),
                lineNumber: NSColor(srgbRed: 0.34, green: 0.34, blue: 0.34, alpha: 1),
                currentLine: NSColor(white: 1, alpha: 0.035),
                selection: NSColor(srgbRed: 0.31, green: 0.58, blue: 0.98, alpha: 0.42),
                guide: NSColor(white: 1, alpha: 0.085),
                activeGuide: NSColor(white: 1, alpha: 0.24),
                divider: NSColor(srgbRed: 0.204, green: 0.212, blue: 0.231, alpha: 1),
                keyword: NSColor(srgbRed: 0.812, green: 0.557, blue: 0.427, alpha: 1),
                number: NSColor(srgbRed: 0.165, green: 0.675, blue: 0.722, alpha: 1),
                string: NSColor(srgbRed: 0.416, green: 0.671, blue: 0.451, alpha: 1),
                comment: NSColor(srgbRed: 0.380, green: 0.510, blue: 0.416, alpha: 1),
                callable: NSColor(srgbRed: 0.337, green: 0.659, blue: 0.957, alpha: 1),
                property: NSColor(srgbRed: 0.780, green: 0.490, blue: 0.733, alpha: 1),
                annotation: NSColor(srgbRed: 0.910, green: 0.630, blue: 0.200, alpha: 1)
            )
        }
        return Self(
            background: .white,
            text: NSColor(srgbRed: 0.122, green: 0.137, blue: 0.161, alpha: 1),
            lineNumber: NSColor(srgbRed: 0.43, green: 0.45, blue: 0.49, alpha: 1),
            currentLine: NSColor(white: 0, alpha: 0.035),
            selection: NSColor(srgbRed: 0.208, green: 0.455, blue: 0.941, alpha: 0.24),
            guide: NSColor(white: 0, alpha: 0.11),
            activeGuide: NSColor(white: 0, alpha: 0.27),
            divider: NSColor(srgbRed: 0.78, green: 0.79, blue: 0.81, alpha: 1),
            keyword: NSColor(srgbRed: 0.64, green: 0.27, blue: 0.12, alpha: 1),
            number: NSColor(srgbRed: 0.0, green: 0.45, blue: 0.52, alpha: 1),
            string: NSColor(srgbRed: 0.19, green: 0.48, blue: 0.22, alpha: 1),
            comment: NSColor(srgbRed: 0.32, green: 0.48, blue: 0.35, alpha: 1),
            callable: NSColor(srgbRed: 0.08, green: 0.36, blue: 0.72, alpha: 1),
            property: NSColor(srgbRed: 0.55, green: 0.18, blue: 0.64, alpha: 1),
            annotation: NSColor(srgbRed: 0.63, green: 0.38, blue: 0.02, alpha: 1)
        )
    }
}

final class IDECodeTextView: NSTextView {
    var indentationWidth = 4
    private var palette = EditorCodePalette.current()

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyEditorAppearance()
    }

    func applyEditorAppearance() {
        palette = EditorCodePalette.current(for: effectiveAppearance)
        backgroundColor = palette.background
        textColor = palette.text
        insertionPointColor = .white
        selectedTextAttributes = [
            .backgroundColor: palette.selection,
            .foregroundColor: palette.text
        ]
        needsDisplay = true
    }

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        drawCurrentLine(in: rect)
        drawIndentGuides(in: rect)
    }

    private func drawCurrentLine(in dirtyRect: NSRect) {
        guard let layoutManager, layoutManager.numberOfGlyphs > 0 else { return }
        let source = string as NSString
        let caret = min(selectedRange().location, source.length)
        let lineRange = source.lineRange(for: NSRange(location: caret, length: 0))
        let glyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
        guard glyphRange.location < layoutManager.numberOfGlyphs else { return }

        var fragmentRange = NSRange()
        var glyph = glyphRange.location
        while glyph < NSMaxRange(glyphRange) {
            let fragment = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: &fragmentRange)
            let highlight = NSRect(
                x: visibleRect.minX + 1,
                y: textContainerOrigin.y + fragment.minY,
                width: max(0, visibleRect.width - 2),
                height: fragment.height
            )
            if highlight.intersects(dirtyRect) {
                palette.currentLine.setFill()
                highlight.intersection(dirtyRect).fill()
            }
            let next = NSMaxRange(fragmentRange)
            guard next > glyph else { break }
            glyph = next
        }
    }

    private func drawIndentGuides(in dirtyRect: NSRect) {
        guard let layoutManager, let textContainer, layoutManager.numberOfGlyphs > 0,
              let font else { return }
        let source = string as NSString
        let width = max(1, indentationWidth)
        let spaceWidth = (" " as NSString).size(withAttributes: [.font: font]).width
        let caretIndent = leadingIndentation(at: min(selectedRange().location, source.length), source: source)
        let containerRect = dirtyRect.offsetBy(dx: -textContainerOrigin.x, dy: -textContainerOrigin.y)
        let visibleGlyphs = layoutManager.glyphRange(forBoundingRect: containerRect, in: textContainer)

        layoutManager.enumerateLineFragments(forGlyphRange: visibleGlyphs) { [weak self] rect, _, _, glyphRange, _ in
            guard let self else { return }
            let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            let indent = self.leadingIndentation(at: characterRange.location, source: source)
            guard indent >= width else { return }
            for level in stride(from: width, through: indent, by: width) {
                let x = self.textContainerOrigin.x + CGFloat(level) * spaceWidth
                let y1 = self.textContainerOrigin.y + rect.minY + 2
                let y2 = self.textContainerOrigin.y + rect.maxY - 2
                (caretIndent >= level ? self.palette.activeGuide : self.palette.guide).setStroke()
                let path = NSBezierPath()
                path.lineWidth = 1
                path.move(to: NSPoint(x: x, y: y1))
                path.line(to: NSPoint(x: x, y: y2))
                path.stroke()
            }
        }
    }

    private func leadingIndentation(at location: Int, source: NSString) -> Int {
        let safeLocation = min(max(location, 0), source.length)
        let lineRange = source.lineRange(for: NSRange(location: safeLocation, length: 0))
        var columns = 0
        for index in lineRange.location..<NSMaxRange(lineRange) {
            switch source.character(at: index) {
            case 32: columns += 1
            case 9: columns += indentationWidth - (columns % indentationWidth)
            default: return columns
            }
        }
        return columns
    }
}

enum EditorSyntaxHighlighter {
    private static let keyword = expression(
        #"\b(abstract|as|assert|async|await|break|case|catch|class|const|continue|covariant|default|deferred|do|dynamic|else|enum|export|extends|extension|external|factory|false|final|finally|for|func|function|get|guard|hide|if|implements|import|in|interface|internal|is|late|let|library|mixin|new|nil|null|on|open|operator|package|part|private|protected|protocol|public|required|rethrow|return|sealed|set|show|static|struct|super|switch|sync|this|throw|throws|true|try|typedef|var|void|when|while|with|yield)\b"#
    )
    private static let annotation = expression(#"@[A-Za-z_][A-Za-z0-9_]*"#)
    private static let number = expression(#"\b(?:0x[0-9A-Fa-f]+|\d+(?:\.\d+)?)\b"#)
    private static let callable = expression(#"\b[A-Za-z_][A-Za-z0-9_]*(?=\s*\()"#)
    private static let property = expression(#"\b_[A-Za-z][A-Za-z0-9_]*\b"#)
    private static let string = expression(#"(?:r|R)?\"(?:\\.|[^\"\\])*\"|(?:r|R)?'(?:\\.|[^'\\])*'"#)
    private static let comment = expression(#"//.*$|#.*$|/\*[\s\S]*?\*/"#, options: [.anchorsMatchLines])

    static func apply(to textView: NSTextView) {
        guard let layoutManager = textView.layoutManager else { return }
        let source = textView.string
        let range = NSRange(location: 0, length: (source as NSString).length)
        layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: range)
        guard range.length > 0, range.length <= 500_000 else { return }
        let palette = EditorCodePalette.current(for: textView.effectiveAppearance)
        paint(keyword, palette.keyword, source, range, layoutManager)
        paint(annotation, palette.annotation, source, range, layoutManager)
        paint(number, palette.number, source, range, layoutManager)
        paint(callable, palette.callable, source, range, layoutManager)
        paint(property, palette.property, source, range, layoutManager)
        paint(string, palette.string, source, range, layoutManager)
        paint(comment, palette.comment, source, range, layoutManager)
    }

    private static func paint(
        _ expression: NSRegularExpression,
        _ color: NSColor,
        _ source: String,
        _ range: NSRange,
        _ layoutManager: NSLayoutManager
    ) {
        expression.enumerateMatches(in: source, range: range) { match, _, _ in
            guard let match else { return }
            layoutManager.addTemporaryAttribute(.foregroundColor, value: color, forCharacterRange: match.range)
        }
    }

    private static func expression(
        _ pattern: String,
        options: NSRegularExpression.Options = []
    ) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: options)
    }
}
