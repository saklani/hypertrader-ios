import SwiftUI

struct MarketView: View {
    @State private var market = MarketViewModel()
    @State private var showPicker = false

    /// Bumped after a successful order so `ActivePositionView` and `TradeHistoryView`
    /// re-fire their `.task(id:)` loaders. Also re-fires naturally whenever the
    /// selected asset or wallet address changes (both are part of the child task id).
    @State private var reloadCounter = 0

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack {
                    MarketPickerButton(
                        assetName: market.selectedAsset?.displayName ?? "BTC-USDC"
                    ) {
                        showPicker = true
                    }

                    Spacer()

                    LivePriceLabel(price: market.currentMidPrice)
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 4)

                // Chart is intentionally hidden. When re-enabled, just drop:
                // CandlestickChartView(coin: market.selectedAsset?.name)
                //     .padding(.horizontal, 20)
                //     .padding(.vertical, 16)

                if market.isWalletReady {
                    OrderFormView(
                        asset: market.selectedAsset,
                        assetIndex: market.selectedAsset.flatMap { market.assetIndex(for: $0) },
                        onOrderPlaced: {
                            reloadCounter += 1
                        }
                    )

                    ActivePositionView(
                        asset: market.selectedAsset,
                        assetIndex: market.selectedAsset.flatMap { market.assetIndex(for: $0) },
                        walletAddress: market.walletAddress,
                        midPrices: market.midPrices,
                        reloadToken: reloadCounter
                    )

                    TradeHistoryView(
                        asset: market.selectedAsset,
                        walletAddress: market.walletAddress,
                        reloadToken: reloadCounter
                    )
                } else {
                    ConnectWalletView()
                }
            }
        }
        .sheet(isPresented: $showPicker) {
            MarketPickerSheet(
                assets: market.assetsWithVolume,
                midPrices: market.midPrices
            ) { asset in
                market.selectAsset(asset)
            }
        }
        .task {
            await market.loadMarketData()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                market.onResume()
            }
        }
    }
}

#Preview {
    MarketView()
}
