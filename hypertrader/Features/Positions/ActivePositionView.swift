import SwiftUI

/// Shows the user's active position (if any) for the given asset, with a Close action.
/// Self-contained: owns its own `AssetPositionViewModel` and reloads automatically
/// whenever `asset`, `walletAddress`, or `reloadToken` changes. The parent bumps
/// `reloadToken` after placing an order to force a refresh.
struct ActivePositionView: View {
    let asset: HLAsset?
    let assetIndex: Int?
    let walletAddress: String?
    let midPrices: [String: String]
    let reloadToken: Int

    @State private var position = AssetPositionViewModel()

    var body: some View {
        Group {
            if let activePosition = position.activePosition {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    Text("Active Position")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    PositionRowView(
                        position: activePosition,
                        midPrice: midPrices[activePosition.position.coin],
                        isClosing: position.isClosing,
                        onClose: closePosition
                    )
                    .padding(.horizontal)
                }
            }
        }
        .task(id: reloadKey) {
            await reload()
        }
    }

    // MARK: - Actions

    private var reloadKey: String {
        "\(asset?.name ?? "_")|\(walletAddress ?? "_")|\(reloadToken)"
    }

    private func reload() async {
        guard let asset, let walletAddress else {
            position.clear()
            return
        }
        await position.load(address: walletAddress, coin: asset.name)
    }

    private func closePosition() {
        guard let assetIndex else { return }
        Task {
            await position.closePosition(assetIndex: assetIndex)
            // Close already nils out activePosition on success; also re-fetch
            // from the server for anything else that might have changed.
            await reload()
        }
    }
}
