import SwiftUI

// MARK: - Filter Chip

/// Selectable capsule chip for filter bars.
/// Usage: `FilterChip(title: "Crypto", isSelected: true) { selectCrypto() }`
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.subheadline.weight(isSelected ? .semibold : .regular))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color(.systemGray5))
            .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            .clipShape(Capsule())
    }
}

// MARK: - Status Chip

/// Static label chip for displaying status or category.
/// Usage: `StatusChip("LONG", color: .green)` or `StatusChip("Stocks", color: .blue)`
struct StatusChip: View {
    let text: String
    let color: Color

    init(_ text: String, color: Color) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

#Preview("Chip Styles") {
    VStack(spacing: 16) {
        // Filter chips
        HStack(spacing: 8) {
            FilterChip(title: "All", isSelected: true) {}
            FilterChip(title: "Perps", isSelected: false) {}
            FilterChip(title: "Spot", isSelected: false) {}
            FilterChip(title: "Crypto", isSelected: false) {}
        }

        // Status chips
        HStack(spacing: 8) {
            StatusChip("LONG", color: .green)
            StatusChip("SHORT", color: .red)
            StatusChip("Stocks", color: .blue)
            StatusChip("HIP-3", color: .orange)
        }
    }
    .padding()
}
