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
                StatusChip(pos.isLong ? "LONG" : "SHORT", color: pos.isLong ? .green : .red)

                Spacer()

                Text("\(pos.leverage.value)x")
                    .font(.caption)
            }

            // Details grid
            HStack {
                DetailColumn(label: "Size", value: String(format: "%.4f", pos.absSize), alignment: .leading)
                Spacer()
                DetailColumn(label: "Entry", value: pos.entryPx ?? "--", alignment: .center)
                Spacer()
                DetailColumn(label: "uPnL", value: pnlFormatted, alignment: .trailing)
            }

            // Close button
            Button("Close Position") {
                onClose()
            }
            .buttonStyle(DestructiveActionButtonStyle(isLoading: isClosing))
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
                    leverage: HLLeverage(type: "cross", value: 10, rawUsd: nil),
                    maxLeverage: nil,
                    cumFunding: nil
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
                    leverage: HLLeverage(type: "cross", value: 5, rawUsd: nil),
                    maxLeverage: nil,
                    cumFunding: nil
                )
            ),
            midPrice: "94600.00",
            isClosing: false,
            onClose: {}
        )
    }
}
