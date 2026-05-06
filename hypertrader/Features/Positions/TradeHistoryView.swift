import SwiftUI

/// Shows recent trade fills for the given asset.
/// Self-contained: owns its own `TradeHistoryViewModel` and reloads automatically
/// whenever `asset`, `walletAddress`, or `reloadToken` changes. The parent bumps
/// `reloadToken` after placing an order to force a refresh.
struct TradeHistoryView: View {
    let asset: HLAsset?
    let walletAddress: String?
    let reloadToken: Int

    @State private var history = TradeHistoryViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider().padding(.top, 4)
            Text("Trade History")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 8)

            if history.fills.isEmpty {
                Text("No trades yet")
                    .font(.caption)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
            } else {
                ForEach(history.fills.prefix(20)) { fill in
                    TradeHistoryRow(fill: fill)
                        .padding(.horizontal)
                }
            }
        }
        .padding(.bottom, 20)
        .task(id: reloadKey) {
            await reload()
        }
    }

    // MARK: - Loading

    private var reloadKey: String {
        "\(asset?.name ?? "_")|\(walletAddress ?? "_")|\(reloadToken)"
    }

    private func reload() async {
        guard let asset, let walletAddress else {
            history.clear()
            return
        }
        await history.load(address: walletAddress, coin: asset.name)
    }
}
