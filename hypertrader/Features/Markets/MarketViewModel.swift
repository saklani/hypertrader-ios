import Foundation

/// Asset selection, market data, and live prices.
@Observable
@MainActor
final class MarketViewModel {
    // Asset selection
    @ObservationIgnored
    var selectedAssetName: String {
        get { UserDefaults.standard.string(forKey: "lastSelectedAsset") ?? "BTC" }
        set { UserDefaults.standard.set(newValue, forKey: "lastSelectedAsset") }
    }
    var selectedAsset: HLAsset?

    // Market data
    var assetsWithVolume: [AssetWithVolume] = []
    var isLoadingMarketData = false
    var error: String?

    private let infoService = HyperliquidInfoService.shared
    private let wsService = HyperliquidWebSocketService.shared

    /// Original API-order assets for index lookup.
    private(set) var universeAssets: [HLAsset] = []

    // MARK: - Computed

    var midPrices: [String: String] { wsService.mids }

    var currentMidPrice: String {
        guard let asset = selectedAsset, let raw = midPrices[asset.name] else { return "--" }
        return formatDisplayPrice(raw)
    }

    var currentMidPriceDouble: Double? {
        guard let asset = selectedAsset, let str = midPrices[asset.name] else { return nil }
        return Double(str)
    }

    var walletAddress: String? {
        WalletConnectManager.shared.walletAddress
    }

    func assetIndex(for asset: HLAsset) -> Int? {
        universeAssets.firstIndex(where: { $0.name == asset.name })
    }

    // MARK: - Load

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
                selectedAsset = universeAssets.first(where: { $0.name == selectedAssetName })
                    ?? universeAssets.first
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingMarketData = false
    }

    func selectAsset(_ asset: HLAsset) {
        selectedAsset = asset
        selectedAssetName = asset.name
    }

    // MARK: - Resume

    func onResume() {
        wsService.disconnect()
        wsService.connect()
    }
}
