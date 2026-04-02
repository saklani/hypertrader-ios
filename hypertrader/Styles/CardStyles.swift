import SwiftUI

// MARK: - Surface Card

/// Quaternary background container with rounded corners.
/// Usage: `Text("content").modifier(SurfaceCard())`
struct SurfaceCard: ViewModifier {
    var cornerRadius: CGFloat = 8

    func body(content: Content) -> some View {
        content
            .padding()
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

extension View {
    func surfaceCard(cornerRadius: CGFloat = 8) -> some View {
        modifier(SurfaceCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Badge

/// Colored badge with translucent background.
/// Usage: `Text("+2.31%").badgeStyle(color: .green)` or `Text("LONG").badgeStyle(color: .green, size: .small)`
enum BadgeSize {
    case small   // direction badges (LONG/SHORT)
    case medium  // change % badges
}

struct BadgeModifier: ViewModifier {
    let color: Color
    var size: BadgeSize = .medium

    func body(content: Content) -> some View {
        switch size {
        case .small:
            content
                .font(.caption.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color.opacity(0.2))
                .foregroundStyle(color)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        case .medium:
            content
                .font(.caption.bold().monospaced())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.15))
                .foregroundStyle(color)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

extension View {
    func badgeStyle(color: Color, size: BadgeSize = .medium) -> some View {
        modifier(BadgeModifier(color: color, size: size))
    }
}

#Preview("Card Styles") {
    VStack(spacing: 16) {
        Text("wc:7f6e504bfad60b48...")
            .font(.caption2.monospaced())
            .surfaceCard()

        HStack {
            Text("LONG").badgeStyle(color: .green, size: .small)
            Text("SHORT").badgeStyle(color: .red, size: .small)
        }

        HStack {
            Text("+2.31%").badgeStyle(color: .green)
            Text("-1.14%").badgeStyle(color: .red)
        }
    }
    .padding()
}
