import SwiftUI

/// The Markets tab: chart with active position and trade history inline,
/// plus a FAB for wallet connection or opening the order sheet.
struct MarketView: View {
    @State private var market = MarketViewModel()
    @State private var showPicker = false

    /// Bumped after a successful order so `ActivePositionView` and `TradeHistoryView`
    /// re-fire their `.task(id:)` loaders.
    @State private var reloadCounter = 0

    @Environment(\.scenePhase) private var scenePhase

    private var wcManager: WalletConnectManager { WalletConnectManager.shared }
    private var isWalletReady: Bool { wcManager.isConnected && wcManager.isAgentReady }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                CandlestickChartView(coin: market.selectedAsset?.name)
                    .frame(height: 400)

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
            }
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top) { headerBar }
        .overlay(alignment: .bottom) {
            fab
                .padding(.bottom, 16)
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
            HyperliquidWebSocketService.shared.connect()
            await market.loadMarketData()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                market.onResume()
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 12) {
            MarketPickerButton(
                assetName: market.selectedAsset?.displayName ?? "BTC-USDC"
            ) {
                showPicker = true
            }

            Spacer()

            LivePriceLabel(price: market.currentMidPrice)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - FAB

    @ViewBuilder
    private var fab: some View {
        if isWalletReady {
            OpenPositionButton(
                asset: market.selectedAsset,
                assetIndex: market.selectedAsset.flatMap { market.assetIndex(for: $0) },
                onOrderPlaced: { reloadCounter += 1 }
            )
        } else if wcManager.isConnected {
            ApproveAgentButton()
        } else {
            ConnectWalletButton()
        }
    }
}

#Preview {
    MarketView()
}
