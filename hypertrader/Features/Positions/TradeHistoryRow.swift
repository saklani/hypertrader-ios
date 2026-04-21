import SwiftUI

struct TradeHistoryRow: View {
    let fill: HLFill

    var body: some View {
        HStack {
            StatusChip(fill.isBuy ? "BUY" : "SELL", color: fill.isBuy ? .green : .red)

            Text(String(format: "%.4f", fill.size))
                .font(.caption.monospaced())

            Text("@")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(fill.px)
                .font(.caption.monospaced())

            Spacer()

            Text(fill.date, format: .dateTime.hour().minute())
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    List {
        TradeHistoryRow(fill: HLFill(
            coin: "BTC", side: "B", px: "94500.00", sz: "0.0500",
            time: UInt64(Date().timeIntervalSince1970 * 1000), fee: "0.50", oid: 1,
            tid: nil, closedPnl: nil, hash: nil, crossed: nil, dir: nil, startPosition: nil, feeToken: nil, builderFee: nil
        ))
        TradeHistoryRow(fill: HLFill(
            coin: "BTC", side: "A", px: "93800.00", sz: "0.0200",
            time: UInt64(Date().addingTimeInterval(-3600).timeIntervalSince1970 * 1000), fee: "0.20", oid: 2,
            tid: nil, closedPnl: nil, hash: nil, crossed: nil, dir: nil, startPosition: nil, feeToken: nil, builderFee: nil
        ))
    }
}
