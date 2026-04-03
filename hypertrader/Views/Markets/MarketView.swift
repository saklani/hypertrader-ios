import SwiftUI

struct MarketView: View {
    @State private var vm = AssetDetailViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                MarketPicker(
                    assetName: vm.selectedAsset?.name ?? "BTC",
                    price: vm.currentMidPrice,
                    assets: vm.assetsWithVolume,
                    midPrices: vm.midPrices,
                    searchText: $vm.searchText
                ) { asset in
                    Task { await vm.selectAsset(asset) }
                }

                IntervalPickerBar(
                    intervals: vm.intervals,
                    selected: vm.selectedInterval
                ) { interval in
                    Task { await vm.changeInterval(interval) }
                }

                CandlestickChartView(candles: vm.candles, interval: vm.selectedInterval)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)

                Divider().padding(.horizontal)

                OrderFormView(
                    isWalletReady: vm.isWalletReady,
                    isMarketOrder: $vm.isMarketOrder,
                    sizeText: $vm.sizeText,
                    priceText: $vm.priceText,
                    isPlacingOrder: vm.isPlacingOrder,
                    canPlaceOrder: vm.canPlaceOrder,
                    isBuy: vm.isBuy,
                    orderResult: vm.orderResult,
                    orderError: vm.orderError,
                    activePosition: vm.activePosition,
                    midPrices: vm.midPrices,
                    isClosingPosition: vm.isClosingPosition,
                    fills: vm.assetFills,
                    onBuy: {
                        vm.isBuy = true
                        Task { await vm.placeOrder() }
                    },
                    onSell: {
                        vm.isBuy = false
                        Task { await vm.placeOrder() }
                    },
                    onClosePosition: {
                        Task { await vm.closePosition() }
                    }
                )
            }
        }
        .task {
            await vm.loadAll()
        }
    }
}

#Preview {
    MarketView()
}
