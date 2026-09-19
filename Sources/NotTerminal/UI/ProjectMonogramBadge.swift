import SwiftUI

struct ProjectMonogramBadge: View {
    let monogram: String
    var size: CGFloat = 27

    var body: some View {
        Text(monogram)
            .font(.system(size: size * 0.39, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                Color.accentColor.gradient,
                in: RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}
