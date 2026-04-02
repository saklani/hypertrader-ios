import SwiftUI

struct PositionRowView: View {
    let position: HLAssetPosition
    let midPrice: String?
    let isClosing: Bool
    let onClose: () -> Void

    private var pos: HLPosition { position.position }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: coin + direction
            HStack {
                Text(pos.coin)
                    .font(.headline)
                Text(pos.isLong ? "LONG" : "SHORT")
                    .font(.caption.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(pos.isLong ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    .foregroundStyle(pos.isLong ? .green : .red)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Spacer()

                // Leverage
                Text("\(pos.leverage.value)x")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Details grid
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Size")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.4f", pos.absSize))
                        .font(.caption.monospaced())
                }

                Spacer()

                VStack(alignment: .center, spacing: 2) {
                    Text("Entry")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(pos.entryPx ?? "--")
                        .font(.caption.monospaced())
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("uPnL")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(pnlFormatted)
                        .font(.caption.monospaced().bold())
                        .foregroundStyle(pos.pnl >= 0 ? .green : .red)
                }
            }

            // Close button
            Button(role: .destructive) {
                onClose()
            } label: {
                HStack {
                    Spacer()
                    if isClosing {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text("Close Position")
                        .font(.subheadline.bold())
                    Spacer()
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .disabled(isClosing)
        }
        .padding(.vertical, 4)
    }

    private var pnlFormatted: String {
        let pnl = pos.pnl
        let sign = pnl >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", pnl))"
    }
}

#Preview("Long Position") {
    List {
        PositionRowView(
            position: HLAssetPosition(
                type: "oneWay",
                position: HLPosition(
                    coin: "ETH",
                    szi: "1.5000",
                    entryPx: "3200.00",
                    positionValue: "4800.00",
                    unrealizedPnl: "150.00",
                    returnOnEquity: "0.03",
                    liquidationPx: "2800.00",
                    marginUsed: "480.00",
                    leverage: HLLeverage(type: "cross", value: 10)
                )
            ),
            midPrice: "3300.00",
            isClosing: false,
            onClose: {}
        )
    }
}

#Preview("Short Position - Losing") {
    List {
        PositionRowView(
            position: HLAssetPosition(
                type: "oneWay",
                position: HLPosition(
                    coin: "BTC",
                    szi: "-0.0500",
                    entryPx: "94000.00",
                    positionValue: "4700.00",
                    unrealizedPnl: "-230.50",
                    returnOnEquity: "-0.05",
                    liquidationPx: "99000.00",
                    marginUsed: "940.00",
                    leverage: HLLeverage(type: "cross", value: 5)
                )
            ),
            midPrice: "94600.00",
            isClosing: false,
            onClose: {}
        )
    }
}
