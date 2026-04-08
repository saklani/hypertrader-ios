import Foundation

/// Asset paired with its 24h volume and previous day price, for display in the asset picker and markets.
struct AssetWithVolume: Identifiable, Hashable {
    let asset: HLAsset
    let dayNtlVlm: Double
    let prevDayPx: Double
    var id: String { asset.name }
}

enum MarketFilter: String, CaseIterable {
    case all = "All"
    case perps = "Perps"
    case spot = "Spot"
    case crypto = "Crypto"
    case tradFi = "TradFi"
    case hip3 = "HIP-3"
}

/// Unified market item combining perps and spot data for the Markets tab.
struct MarketItem: Identifiable, Hashable {
    let name: String
    let rawName: String
    let dayNtlVlm: Double
    let prevDayPx: Double
    let isSpot: Bool
    let isBuilderPerp: Bool
    let category: String?
    var id: String { rawName }
}
