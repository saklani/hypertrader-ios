import Foundation

/// Manages trading state: asset list, prices, and order submission.
@Observable
@MainActor
final class TradingViewModel {
    // Market data (sorted by volume)
    var assetsWithVolume: [AssetWithVolume] = []
    var selectedAsset: HLAsset?
    var searchText = ""

    // Order form
    var isBuy = true
    var isMarketOrder = true
    var sizeText = ""
    var priceText = ""

    // Status
    var isPlacingOrder = false
    var orderResult: String?
    var orderError: String?
    var isLoadingMarketData = false

    private let infoService = HyperliquidInfoService.shared
    private let exchangeService = HyperliquidExchangeService.shared
    private let wsService = HyperliquidWebSocketService.shared

    /// Original API-order assets for correct index lookup in order submission.
    private var universeAssets: [HLAsset] = []

    // MARK: - Computed

    /// Real-time prices from WebSocket.
    var midPrices: [String: String] { wsService.mids }

    /// Assets filtered by search text (already sorted by volume).
    var filteredAssets: [AssetWithVolume] {
        if searchText.isEmpty { return assetsWithVolume }
        return assetsWithVolume.filter {
            $0.asset.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Look up the correct API index for an asset (universe order, not volume order).
    func assetIndex(for asset: HLAsset) -> Int? {
        universeAssets.firstIndex(where: { $0.name == asset.name })
    }

    // MARK: - Market Data

    func loadMarketData() async {
        isLoadingMarketData = true
        do {
            let result = try await infoService.getMetaAndAssetCtxs()
            universeAssets = result.meta.universe

            assetsWithVolume = zip(result.meta.universe, result.assetCtxs)
                .map { asset, ctx in
                    AssetWithVolume(
                        asset: asset,
                        dayNtlVlm: Double(ctx.dayNtlVlm) ?? 0,
                        prevDayPx: Double(ctx.prevDayPx) ?? 0
                    )
                }
                .sorted { $0.dayNtlVlm > $1.dayNtlVlm }

            if selectedAsset == nil {
                selectedAsset = assetsWithVolume.first?.asset
            }
        } catch {
            orderError = "Failed to load market data: \(error.localizedDescription)"
        }
        isLoadingMarketData = false
    }

    // MARK: - Order Placement

    var currentMidPrice: String {
        guard let asset = selectedAsset else { return "--" }
        return midPrices[asset.name] ?? "--"
    }

    var currentMidPriceDouble: Double? {
        Double(currentMidPrice)
    }

    var canPlaceOrder: Bool {
        guard selectedAsset != nil,
              let size = Double(sizeText), size > 0 else { return false }
        if !isMarketOrder {
            guard let price = Double(priceText), price > 0 else { return false }
        }
        return true
    }

    func placeOrder() async {
        guard let asset = selectedAsset,
              let assetIndex = assetIndex(for: asset) else { return }

        let price: String
        if isMarketOrder {
            guard let midPrice = currentMidPriceDouble else {
                orderError = "No market price available"
                return
            }
            // Slippage: 1% for market orders
            let slippagePrice = isBuy ? midPrice * 1.01 : midPrice * 0.99
            price = String(format: "%.2f", slippagePrice)
        } else {
            price = priceText
        }

        let input = OrderInput(
            asset: asset,
            assetIndex: assetIndex,
            isBuy: isBuy,
            size: sizeText,
            price: price,
            isMarket: isMarketOrder,
            reduceOnly: false
        )

        isPlacingOrder = true
        orderResult = nil
        orderError = nil

        do {
            let response = try await exchangeService.placeOrder(input)
            if response.status == "ok" {
                orderResult = "Order placed successfully"
                sizeText = ""
                priceText = ""
            } else {
                orderError = "Order failed: \(response.status)"
            }
        } catch {
            orderError = error.localizedDescription
        }

        isPlacingOrder = false
    }
}
