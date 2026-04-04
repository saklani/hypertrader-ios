import SwiftUI

struct MarketView: View {
    @State private var market = MarketViewModel()
    @State private var chart = ChartViewModel()
    @State private var order = OrderViewModel()
    @State private var position = AssetPositionViewModel()
    @State private var history = TradeHistoryViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                MarketPicker(
                    assetName: market.selectedAsset?.displayName ?? "BTC/USDC",
                    price: market.currentMidPrice,
                    assets: market.assetsWithVolume,
                    midPrices: market.midPrices,
                    searchText: $market.searchText
                ) { asset in
                    market.selectAsset(asset)
                }

                IntervalPickerBar(
                    intervals: chart.intervals,
                    selected: chart.selectedInterval
                ) { interval in
                    guard let coin = market.selectedAsset?.name else { return }
                    Task { await chart.changeInterval(interval, coin: coin) }
                }

                CandlestickChartView(
                    candles: chart.candles,
                    interval: chart.selectedInterval,
                    currentPrice: market.currentMidPriceDouble
                )
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Divider().padding(.horizontal)

                OrderFormView(
                    isWalletReady: market.isWalletReady,
                    isMarketOrder: $order.isMarketOrder,
                    sizeText: $order.sizeText,
                    priceText: $order.priceText,
                    isPlacingOrder: order.isPlacingOrder,
                    canPlaceOrder: order.canPlaceOrder(asset: market.selectedAsset),
                    isBuy: order.isBuy,
                    orderResult: order.orderResult,
                    orderError: order.orderError,
                    activePosition: position.activePosition,
                    midPrices: market.midPrices,
                    isClosingPosition: position.isClosing,
                    fills: history.fills,
                    onBuy: {
                        order.isBuy = true
                        guard let asset = market.selectedAsset,
                              let idx = market.assetIndex(for: asset) else { return }
                        Task {
                            await order.placeOrder(asset: asset, assetIndex: idx)
                            await reloadPositionAndHistory()
                        }
                    },
                    onSell: {
                        order.isBuy = false
                        guard let asset = market.selectedAsset,
                              let idx = market.assetIndex(for: asset) else { return }
                        Task {
                            await order.placeOrder(asset: asset, assetIndex: idx)
                            await reloadPositionAndHistory()
                        }
                    },
                    onClosePosition: {
                        guard let asset = market.selectedAsset,
                              let idx = market.assetIndex(for: asset) else { return }
                        Task {
                            await position.closePosition(assetIndex: idx)
                            await reloadPositionAndHistory()
                        }
                    }
                )
            }
        }
        .task {
            await market.loadMarketData()
            await loadAllForSelectedAsset()
        }
        .onChange(of: market.selectedAsset) { _, _ in
            Task { await loadAllForSelectedAsset() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                market.onResume()
                Task { await loadAllForSelectedAsset() }
            }
        }
    }

    // MARK: - Helpers

    private func loadAllForSelectedAsset() async {
        guard let asset = market.selectedAsset else { return }
        let coin = asset.name

        await chart.load(coin: coin)
        await reloadPositionAndHistory()
    }

    private func reloadPositionAndHistory() async {
        guard let coin = market.selectedAsset?.name else { return }
        if let address = market.walletAddress {
            await position.load(address: address, coin: coin)
            await history.load(address: address, coin: coin)
        }
    }
}

#Preview {
    MarketView()
}
