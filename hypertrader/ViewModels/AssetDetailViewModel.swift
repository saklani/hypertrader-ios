import Foundation

/// Manages chart, orders, active position, and trade history for a single asset.
@Observable
@MainActor
final class AssetDetailViewModel {
    // Asset selection
    @ObservationIgnored
    var selectedAssetName: String {
        get { UserDefaults.standard.string(forKey: "lastSelectedAsset") ?? "BTC" }
        set { UserDefaults.standard.set(newValue, forKey: "lastSelectedAsset") }
    }
    var selectedAsset: HLAsset?

    // Market data
    var assetsWithVolume: [AssetWithVolume] = []
    var searchText = ""
    var selectedFilter: MarketFilter = .all

    // Chart
    var selectedInterval = "1h"
    var isLoadingCandles = false
    let intervals = ["1m", "5m", "15m", "1h", "4h", "1d"]

    // Order form
    var isBuy = true
    var isMarketOrder = true
    var sizeText = ""
    var priceText = ""
    var isPlacingOrder = false
    var orderResult: String?
    var orderError: String?

    // Position
    var activePosition: HLAssetPosition?
    var isClosingPosition = false

    // Trade history
    var fills: [HLFill] = []

    // Loading
    var isLoadingMarketData = false

    private let infoService = HyperliquidInfoService.shared
    private let exchangeService = HyperliquidExchangeService.shared
    private let wsService = HyperliquidWebSocketService.shared

    /// Original API-order assets for index lookup.
    private var universeAssets: [HLAsset] = []

    // MARK: - Computed

    var midPrices: [String: String] { wsService.mids }
    var candles: [HLCandle] = []

    /// Whether the wallet is connected and agent is approved (ready to trade).
    var isWalletReady: Bool {
        WalletConnectManager.shared.isConnected && KeychainManager.hasAgentKey
    }

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

    /// Fills filtered to the selected asset.
    var assetFills: [HLFill] {
        guard let asset = selectedAsset else { return [] }
        return fills.filter { $0.coin == asset.name }
    }

    var walletAddress: String? {
        WalletConnectManager.shared.walletAddress
    }

    func assetIndex(for asset: HLAsset) -> Int? {
        universeAssets.firstIndex(where: { $0.name == asset.name })
    }

    // MARK: - Market Data (for picker)

    var filteredMarketAssets: [AssetWithVolume] {
        var items = assetsWithVolume
        if !searchText.isEmpty {
            items = items.filter { $0.asset.name.localizedCaseInsensitiveContains(searchText) }
        }
        return items
    }

    // MARK: - Initial Load

    func loadAll() async {
        print("[VM] loadAll started")
        await loadMarketData()
        print("[VM] loadMarketData done, selectedAsset=\(selectedAsset?.name ?? "nil")")
        await loadCandles()
        print("[VM] loadCandles done, candles count=\(candles.count)")
        await loadPositionAndFills()
        print("[VM] loadAll complete")
    }

    func loadMarketData() async {
        isLoadingMarketData = true
        do {
            let result = try await infoService.getMetaAndAssetCtxs()
            universeAssets = result.meta.universe
            print("[VM] Fetched \(universeAssets.count) assets")

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
                selectedAsset = universeAssets.first(where: { $0.name == selectedAssetName })
                    ?? universeAssets.first
                print("[VM] Selected asset: \(selectedAsset?.name ?? "nil") (from persisted: \(selectedAssetName))")
            }
        } catch {
            print("[VM] loadMarketData FAILED: \(error)")
            orderError = "Failed to load market data: \(error.localizedDescription)"
        }
        isLoadingMarketData = false
    }

    // MARK: - Asset Selection

    func selectAsset(_ asset: HLAsset) async {
        selectedAsset = asset
        selectedAssetName = asset.name
        candles = []
        orderResult = nil
        orderError = nil
        await loadCandles()
        await loadPositionAndFills()
    }

    // MARK: - Chart

    func loadCandles() async {
        guard let asset = selectedAsset else { return }
        isLoadingCandles = true

        let now = UInt64(Date().timeIntervalSince1970 * 1000)
        let intervalMs = candleIntervalMs(selectedInterval)
        let startTime = now - intervalMs * 200

        do {
            let snapshot = try await infoService.getCandleSnapshot(
                coin: asset.name,
                interval: selectedInterval,
                startTime: startTime,
                endTime: now
            )
            print("[Chart] Loaded \(snapshot.count) candles for \(asset.name) \(selectedInterval)")
            candles = snapshot
            wsService.subscribeCandles(coin: asset.name, interval: selectedInterval)
        } catch {
            print("[Chart] Failed to load candles: \(error)")
        }

        isLoadingCandles = false
    }

    func changeInterval(_ interval: String) async {
        selectedInterval = interval
        await loadCandles()
    }

    private func candleIntervalMs(_ interval: String) -> UInt64 {
        switch interval {
        case "1m": return 60_000
        case "5m": return 300_000
        case "15m": return 900_000
        case "1h": return 3_600_000
        case "4h": return 14_400_000
        case "1d": return 86_400_000
        default: return 3_600_000
        }
    }

    // MARK: - Position & Fills

    func loadPositionAndFills() async {
        guard let address = walletAddress, let asset = selectedAsset else { return }

        do {
            async let stateResult = infoService.getClearinghouseState(address: address)
            async let fillsResult = infoService.getUserFills(address: address)

            let state = try await stateResult
            let allFills = try await fillsResult

            // Find active position for this asset
            activePosition = state.assetPositions.first {
                $0.position.coin == asset.name && (Double($0.position.szi) ?? 0) != 0
            }

            // Filter fills to this asset, most recent first
            fills = allFills
                .filter { $0.coin == asset.name }
                .sorted { $0.time > $1.time }
        } catch {
            // Silently fail
        }
    }

    // MARK: - Place Order

    func placeOrder() async {
        guard let asset = selectedAsset,
              let assetIndex = assetIndex(for: asset) else { return }

        let price: String
        if isMarketOrder {
            guard let midPrice = currentMidPriceDouble else {
                orderError = "No market price available"
                return
            }
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
                // Refresh position and fills
                await loadPositionAndFills()
            } else {
                orderError = "Order failed: \(response.status)"
            }
        } catch {
            orderError = error.localizedDescription
        }

        isPlacingOrder = false
    }

    // MARK: - Close Position

    func closePosition() async {
        guard let position = activePosition,
              let asset = selectedAsset,
              let assetIndex = assetIndex(for: asset),
              let midPriceStr = midPrices[asset.name],
              let midPrice = Double(midPriceStr) else { return }

        isClosingPosition = true

        do {
            let response = try await exchangeService.closePosition(
                position: position.position,
                assetIndex: assetIndex,
                currentMidPrice: midPrice
            )
            if response.status == "ok" {
                await loadPositionAndFills()
            }
        } catch {
            orderError = error.localizedDescription
        }

        isClosingPosition = false
    }
}
