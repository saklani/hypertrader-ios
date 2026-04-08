import Foundation

// MARK: - Asset Metadata

struct HLAssetMeta: Codable {
    let universe: [HLAsset]
}

struct HLAsset: Codable, Identifiable, Hashable {
    let name: String
    let szDecimals: Int
    let maxLeverage: Int
    let onlyIsolated: Bool?
    let isDelisted: Bool?
    var id: String { name }
    var displayName: String {
        name.contains("/") ? name : "\(name)/USDC"
    }
}

// MARK: - Clearinghouse State (Positions + Margin)

struct HLClearinghouseState: Codable {
    let marginSummary: HLMarginSummary
    let crossMarginSummary: HLMarginSummary
    let crossMaintenanceMarginUsed: String?
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
    let maxLeverage: Int?
    let cumFunding: HLCumFunding?

    var isLong: Bool { (Double(szi) ?? 0) > 0 }
    var absSize: Double { abs(Double(szi) ?? 0) }
    var pnl: Double { Double(unrealizedPnl) ?? 0 }
}

struct HLLeverage: Codable {
    let type: String
    let value: Int
    let rawUsd: String?
}

struct HLCumFunding: Codable {
    let allTime: String
    let sinceChange: String
    let sinceOpen: String
}

// MARK: - Asset Context (volume, mark price, etc.)

struct HLAssetCtx: Codable {
    let dayNtlVlm: String
    let markPx: String
    let midPx: String?
    let prevDayPx: String
    let funding: String?
    let openInterest: String?
    let oraclePx: String?
    let premium: String?
    let impactPxs: [String]?
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
    let szDecimals: Int?
    let weiDecimals: Int?
    let tokenId: String?
    let isCanonical: Bool?
    let fullName: String?
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

// MARK: - Perp Dex (from perpDexs endpoint)

/// A builder dex from the `perpDexs` endpoint. Element 0 is null (native dex).
struct HLPerpDex: Codable {
    let name: String
    let fullName: String?
    let deployer: String?
}

// MARK: - Candle (OHLCV)

/// OHLCV candle. API returns price fields as strings.
nonisolated struct HLCandle: Codable, Identifiable, Sendable {
    let t: UInt64   // open time (ms)
    let T: UInt64   // close time (ms)
    let s: String   // coin symbol
    let i: String   // interval
    let o: String   // open price
    let c: String   // close price
    let h: String   // high price
    let l: String   // low price
    let v: String   // volume (base)
    let n: Int      // number of trades

    var id: UInt64 { t }
    var open: Double { Double(o) ?? 0 }
    var close: Double { Double(c) ?? 0 }
    var high: Double { Double(h) ?? 0 }
    var low: Double { Double(l) ?? 0 }
    var volume: Double { Double(v) ?? 0 }
    var time: Date { Date(timeIntervalSince1970: Double(t) / 1000) }
    var isBullish: Bool { close >= open }
}

// MARK: - Trade Fills (history)

struct HLFill: Codable, Identifiable {
    let coin: String
    let side: String        // "B" (buy) or "A" (sell/ask)
    let px: String
    let sz: String
    let time: UInt64
    let fee: String
    let oid: Int
    let tid: Int?           // unique trade id
    let closedPnl: String?  // realized PnL from this fill
    let hash: String?       // L1 transaction hash
    let crossed: Bool?      // true = taker, false = maker
    let dir: String?        // direction description for display
    let startPosition: String?
    let feeToken: String?
    let builderFee: String?

    var id: String {
        if let tid { return "\(tid)" }
        return "\(oid)-\(time)"
    }
    var isBuy: Bool { side == "B" }
    var price: Double { Double(px) ?? 0 }
    var size: Double { Double(sz) ?? 0 }
    var date: Date { Date(timeIntervalSince1970: Double(time) / 1000) }
    var realizedPnl: Double? {
        guard let pnl = closedPnl else { return nil }
        return Double(pnl)
    }
}

// MARK: - Order Wire Format (for MessagePack encoding)

nonisolated struct HLOrderWire: Codable, Sendable {
    let a: Int       // asset index
    let b: Bool      // isBuy
    let p: String    // price (no trailing zeros)
    let s: String    // size (no trailing zeros)
    let r: Bool      // reduceOnly
    let t: HLOrderTypeWire
    let c: String?   // optional cloid — always encoded (nil = msgpack nil), required by HL wire format

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(a, forKey: .a)
        try container.encode(b, forKey: .b)
        try container.encode(p, forKey: .p)
        try container.encode(s, forKey: .s)
        try container.encode(r, forKey: .r)
        try container.encode(t, forKey: .t)
        if let c {
            try container.encode(c, forKey: .c)
        } else {
            try container.encodeNil(forKey: .c)
        }
    }
}

nonisolated struct HLOrderTypeWire: Codable, Sendable {
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

nonisolated struct HLLimitWire: Codable, Sendable {
    let tif: String // "Gtc", "Ioc", "Alo"
}

nonisolated struct HLTriggerWire: Codable, Sendable {
    let isMarket: Bool
    let triggerPx: String
    let tpsl: String // "tp" or "sl"
}

// MARK: - Builder Fee

nonisolated struct HLBuilderWire: Codable, Sendable {
    let b: String   // builder address
    let f: Int      // fee rate in tenths of a basis point (10 = 1bp = 0.01%)
}

// MARK: - Actions (for MessagePack encoding)

nonisolated struct HLOrderAction: Codable, Sendable {
    var type: String = "order"
    let orders: [HLOrderWire]
    let grouping: String // "na", "normalTpsl", "positionTpsl"
    let builder: HLBuilderWire?
}

nonisolated struct HLCancelAction: Codable, Sendable {
    var type: String = "cancel"
    let cancels: [HLCancelWire]
}

nonisolated struct HLCancelWire: Codable, Sendable {
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

