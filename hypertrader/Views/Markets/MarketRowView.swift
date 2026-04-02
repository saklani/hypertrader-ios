import SwiftUI

struct MarketRowView: View {
    let coin: String
    let price: Double?
    let change24h: Double?
    let volume: Double

    var body: some View {
        HStack {
            Text(coin)
                .font(.body.bold())
                .frame(width: 60, alignment: .leading)

            Spacer()

            Text(formattedPrice)
                .font(.body.monospaced())

            Spacer()

            Text(formattedChange)
                .font(.caption.bold().monospaced())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(changeColor.opacity(0.15))
                .foregroundStyle(changeColor)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(width: 80)

            Text(formattedVolume)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Formatting

    private var formattedPrice: String {
        guard let price else { return "--" }
        if price >= 1000 {
            return String(format: "$%.2f", price)
        } else if price >= 1 {
            return String(format: "$%.4f", price)
        } else {
            return String(format: "$%.6f", price)
        }
    }

    private var formattedChange: String {
        guard let change24h else { return "--" }
        let sign = change24h >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", change24h))%"
    }

    private var changeColor: Color {
        guard let change24h else { return .secondary }
        return change24h >= 0 ? .green : .red
    }

    private var formattedVolume: String {
        if volume >= 1_000_000_000 {
            return String(format: "$%.1fB", volume / 1_000_000_000)
        } else if volume >= 1_000_000 {
            return String(format: "$%.1fM", volume / 1_000_000)
        } else if volume >= 1_000 {
            return String(format: "$%.0fK", volume / 1_000)
        }
        return String(format: "$%.0f", volume)
    }
}

#Preview("Positive") {
    List {
        MarketRowView(coin: "BTC", price: 95123.50, change24h: 2.31, volume: 1_250_000_000)
        MarketRowView(coin: "ETH", price: 3200.10, change24h: -1.14, volume: 890_000_000)
        MarketRowView(coin: "SOL", price: 142.30, change24h: 5.67, volume: 320_000_000)
        MarketRowView(coin: "HYPE", price: 14.32, change24h: 0.45, volume: 45_000_000)
        MarketRowView(coin: "DOGE", price: 0.1742, change24h: -3.21, volume: 12_500_000)
    }
}
