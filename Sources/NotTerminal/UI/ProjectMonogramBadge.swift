import SwiftUI

struct WorkspaceAccentPalette {
    let leading: Color
    let trailing: Color

    var gradient: LinearGradient {
        LinearGradient(
            colors: [leading, trailing],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func at(_ index: Int) -> WorkspaceAccentPalette {
        palettes[index.modulo(palettes.count)]
    }

    private static let palettes = [
        WorkspaceAccentPalette(
            leading: Color(red: 0.18, green: 0.56, blue: 1.00),
            trailing: Color(red: 0.00, green: 0.38, blue: 0.94)
        ),
        WorkspaceAccentPalette(
            leading: Color(red: 0.63, green: 0.39, blue: 1.00),
            trailing: Color(red: 0.42, green: 0.22, blue: 0.88)
        ),
        WorkspaceAccentPalette(
            leading: Color(red: 0.12, green: 0.76, blue: 0.55),
            trailing: Color(red: 0.02, green: 0.55, blue: 0.42)
        ),
        WorkspaceAccentPalette(
            leading: Color(red: 1.00, green: 0.58, blue: 0.20),
            trailing: Color(red: 0.94, green: 0.35, blue: 0.10)
        ),
        WorkspaceAccentPalette(
            leading: Color(red: 0.96, green: 0.34, blue: 0.58),
            trailing: Color(red: 0.78, green: 0.16, blue: 0.42)
        ),
        WorkspaceAccentPalette(
            leading: Color(red: 0.10, green: 0.72, blue: 0.82),
            trailing: Color(red: 0.02, green: 0.50, blue: 0.66)
        ),
        WorkspaceAccentPalette(
            leading: Color(red: 0.36, green: 0.45, blue: 0.98),
            trailing: Color(red: 0.22, green: 0.25, blue: 0.76)
        ),
        WorkspaceAccentPalette(
            leading: Color(red: 0.96, green: 0.34, blue: 0.31),
            trailing: Color(red: 0.78, green: 0.16, blue: 0.20)
        ),
    ]
}

private extension Int {
    func modulo(_ divisor: Int) -> Int {
        let remainder = self % divisor
        return remainder >= 0 ? remainder : remainder + divisor
    }
}

struct ProjectMonogramBadge: View {
    let monogram: String
    var palette = WorkspaceAccentPalette.at(0)
    var size: CGFloat = 27

    var body: some View {
        Text(monogram)
            .font(.system(size: size * 0.39, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                palette.gradient,
                in: RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}
