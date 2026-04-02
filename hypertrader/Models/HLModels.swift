import Foundation

// MARK: - Asset Metadata

struct HLAssetMeta: Codable {
    let universe: [HLAsset]
}

struct HLAsset: Codable, Identifiable, Hashable {
    let name: String
    let szDecimals: Int
    var id: String { name }
}

// MARK: - Clearinghouse State (Positions + Margin)

struct HLClearinghouseState: Codable {
    let marginSummary: HLMarginSummary
    let crossMarginSummary: HLMarginSummary
    let withdrawable: String
    let assetPositions: [HLAssetPosition]
}

struct HLMarginSummary: Codable {
    let accountValue: String
    let totalNtlPos: String
    let totalRawUsd: String
    let totalMarginUsed: String
}

struct HLAssetPosition: Codable, Identifiable {
    let type: String
    let position: HLPosition
    var id: String { position.coin }
}

struct HLPosition: Codable {
    let coin: String
    let szi: String
    let entryPx: String?
    let positionValue: String
    let unrealizedPnl: String
    let returnOnEquity: String
    let liquidationPx: String?
    let marginUsed: String
    let leverage: HLLeverage

    var isLong: Bool { (Double(szi) ?? 0) > 0 }
    var absSize: Double { abs(Double(szi) ?? 0) }
    var pnl: Double { Double(unrealizedPnl) ?? 0 }
}

struct HLLeverage: Codable {
    let type: String
    let value: Int
}

// MARK: - Asset Context (volume, mark price, etc.)

struct HLAssetCtx: Codable {
    let dayNtlVlm: String
    let markPx: String
    let midPx: String?
    let prevDayPx: String
}

/// Response from `metaAndAssetCtxs` — a heterogeneous JSON array: [HLAssetMeta, [HLAssetCtx]]
struct HLMetaAndAssetCtxs: Decodable {
    let meta: HLAssetMeta
    let assetCtxs: [HLAssetCtx]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        meta = try container.decode(HLAssetMeta.self)
        assetCtxs = try container.decode([HLAssetCtx].self)
    }
}

/// Asset paired with its 24h volume and previous day price, for display in the asset picker and markets.
struct AssetWithVolume: Identifiable, Hashable {
    let asset: HLAsset
    let dayNtlVlm: Double
    let prevDayPx: Double
    var id: String { asset.name }
}

// MARK: - Market Filter

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
    let name: String          // display name (e.g. "BTC", "TSLA", "PURR/USDC")
    let rawName: String       // API name (e.g. "xyz:TSLA")
    let dayNtlVlm: Double
    let prevDayPx: Double
    let isSpot: Bool
    let isBuilderPerp: Bool   // has ":" in rawName = HIP-3
    let category: String?     // from perpCategories: "stocks", "crypto", etc.
    var id: String { rawName }
}

// MARK: - Spot Models

/// Response from `spotMetaAndAssetCtxs` — heterogeneous JSON array: [HLSpotMeta, [HLSpotAssetCtx]]
struct HLSpotMetaAndAssetCtxs: Decodable {
    let meta: HLSpotMeta
    let assetCtxs: [HLSpotAssetCtx]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        meta = try container.decode(HLSpotMeta.self)
        assetCtxs = try container.decode([HLSpotAssetCtx].self)
    }
}

struct HLSpotMeta: Codable {
    let tokens: [HLSpotToken]
    let universe: [HLSpotPair]
}

struct HLSpotToken: Codable {
    let name: String
    let index: Int
}

struct HLSpotPair: Codable {
    let name: String
    let tokens: [Int]
    let index: Int
    let isCanonical: Bool
}

struct HLSpotAssetCtx: Codable {
    let dayNtlVlm: String
    let markPx: String
    let midPx: String?
    let prevDayPx: String
}

// MARK: - Order Wire Format (for MessagePack encoding)

struct HLOrderWire: Codable, Sendable {
    let a: Int       // asset index
    let b: Bool      // isBuy
    let p: String    // price (no trailing zeros)
    let s: String    // size (no trailing zeros)
    let r: Bool      // reduceOnly
    let t: HLOrderTypeWire
    let c: String?   // optional cloid
}

struct HLOrderTypeWire: Codable, Sendable {
    let limit: HLLimitWire?
    let trigger: HLTriggerWire?

    init(limit: HLLimitWire) {
        self.limit = limit
        self.trigger = nil
    }

    init(trigger: HLTriggerWire) {
        self.limit = nil
        self.trigger = trigger
    }
}

struct HLLimitWire: Codable, Sendable {
    let tif: String // "Gtc", "Ioc", "Alo"
}

struct HLTriggerWire: Codable, Sendable {
    let isMarket: Bool
    let triggerPx: String
    let tpsl: String // "tp" or "sl"
}

// MARK: - Builder Fee

struct HLBuilderWire: Codable, Sendable {
    let b: String   // builder address
    let f: Int      // fee rate in tenths of a basis point (10 = 1bp = 0.01%)
}

// MARK: - Actions (for MessagePack encoding)

struct HLOrderAction: Codable, Sendable {
    var type: String = "order"
    let orders: [HLOrderWire]
    let grouping: String // "na", "normalTpsl", "positionTpsl"
    let builder: HLBuilderWire?
}

struct HLCancelAction: Codable, Sendable {
    var type: String = "cancel"
    let cancels: [HLCancelWire]
}

struct HLCancelWire: Codable, Sendable {
    let a: Int // asset index
    let o: Int // order id
}

// MARK: - Exchange Request/Response

struct HLSignature: Codable {
    let r: String
    let s: String
    let v: Int
}

struct HLExchangeResponse: Codable {
    let status: String
    let response: HLExchangeResponseData?
}

struct HLExchangeResponseData: Codable {
    let type: String
    let data: HLExchangeResponseStatuses?
}

struct HLExchangeResponseStatuses: Codable {
    let statuses: [HLOrderStatus]
}

struct HLOrderStatus: Codable {
    let resting: HLRestingOrder?
    let filled: HLFilledOrder?
    let error: String?
}

struct HLRestingOrder: Codable {
    let oid: Int
}

struct HLFilledOrder: Codable {
    let totalSz: String
    let avgPx: String
    let oid: Int
}

// MARK: - Open Orders

struct HLOpenOrder: Codable, Identifiable {
    let coin: String
    let side: String
    let limitPx: String
    let sz: String
    let oid: Int
    let timestamp: UInt64
    var id: Int { oid }
}

// MARK: - Order Input (app-facing)

struct OrderInput {
    let asset: HLAsset
    let assetIndex: Int
    let isBuy: Bool
    let size: String
    let price: String
    let isMarket: Bool
    let reduceOnly: Bool

    func toWire(slippagePrice: String? = nil) -> HLOrderWire {
        let effectivePrice = isMarket ? (slippagePrice ?? price) : price
        let orderType: HLOrderTypeWire = isMarket
            ? HLOrderTypeWire(limit: HLLimitWire(tif: "Ioc"))
            : HLOrderTypeWire(limit: HLLimitWire(tif: "Gtc"))

        return HLOrderWire(
            a: assetIndex,
            b: isBuy,
            p: formatPrice(effectivePrice),
            s: formatPrice(size),
            r: reduceOnly,
            t: orderType,
            c: nil
        )
    }
}

// MARK: - Helpers

/// Remove trailing zeros from a decimal string (Hyperliquid requirement)
func formatPrice(_ value: String) -> String {
    guard let decimal = Decimal(string: value) else { return value }
    let formatted = NSDecimalNumber(decimal: decimal).stringValue
    return formatted
}

