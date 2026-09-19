import AppKit
import CoreText

enum BundledFontRegistry {
    private static let fonts = [
        "JetBrainsMono-Regular",
        "JetBrainsMono-Italic",
        "JetBrainsMono-Bold"
    ]

    static func registerFonts() {
        for font in fonts where NSFont(name: font, size: 13) == nil {
            guard let url = Bundle.module.url(forResource: font, withExtension: "ttf") else {
                continue
            }
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        }
    }

    static func editorFont(size: CGFloat, italic: Bool = false) -> NSFont {
        let name = italic ? "JetBrainsMono-Italic" : "JetBrainsMono-Regular"
        return NSFont(name: name, size: size)
            ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }
}
