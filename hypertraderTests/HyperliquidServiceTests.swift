import Testing
@testable import hypertrader
import Foundation

// MARK: - HLCandle Decoding Tests

@Suite("HLCandle Decoding")
@MainActor struct HLCandleDecodingTests {

    // Real candle JSON from Hyperliquid testnet API (verified via Python)
    static let realCandleJSON = """
    {"t":1774486800000,"T":1774490399999,"s":"BTC","i":"1h","o":"72538.0","c":"72824.0","h":"73086.0","l":"71344.0","v":"1.50051","n":611}
    """

    @Test func decodesRealCandleJSON() throws {
        let data = HLCandleDecodingTests.realCandleJSON.data(using: .utf8)!
        let candle = try JSONDecoder().decode(HLCandle.self, from: data)

        #expect(candle.t == 1774486800000)
        #expect(candle.T == 1774490399999)
        #expect(candle.s == "BTC")
        #expect(candle.i == "1h")
        #expect(candle.open == 72538.0)
        #expect(candle.close == 72824.0)
        #expect(candle.high == 73086.0)
        #expect(candle.low == 71344.0)
        #expect(candle.volume == 1.50051)
        #expect(candle.n == 611)
    }

    @Test func computedPropertiesWork() throws {
        let data = HLCandleDecodingTests.realCandleJSON.data(using: .utf8)!
        let candle = try JSONDecoder().decode(HLCandle.self, from: data)

        #expect(candle.open == 72538.0)
        #expect(candle.close == 72824.0)
        #expect(candle.high == 73086.0)
        #expect(candle.low == 71344.0)
        #expect(candle.volume == 1.50051)
        #expect(candle.isBullish == true) // close > open
        #expect(candle.id == 1774486800000)
    }

    @Test func bearishCandleDetected() throws {
        let json = """
        {"t":1774486800000,"T":1774490399999,"s":"ETH","i":"1h","o":"3000.0","c":"2900.0","h":"3050.0","l":"2850.0","v":"100.0","n":50}
        """
        let candle = try JSONDecoder().decode(HLCandle.self, from: json.data(using: .utf8)!)
        #expect(candle.isBullish == false) // close < open
    }

    @Test func timeConversion() throws {
        let data = HLCandleDecodingTests.realCandleJSON.data(using: .utf8)!
        let candle = try JSONDecoder().decode(HLCandle.self, from: data)
        let expectedDate = Date(timeIntervalSince1970: 1774486800.0)
        #expect(candle.time == expectedDate)
    }

    @Test func decodesArrayOfCandles() throws {
        let json = """
        [
            {"t":1774486800000,"T":1774490399999,"s":"BTC","i":"1h","o":"72538.0","c":"72824.0","h":"73086.0","l":"71344.0","v":"1.50051","n":611},
            {"t":1774490400000,"T":1774493999999,"s":"BTC","i":"1h","o":"72824.0","c":"73100.0","h":"73200.0","l":"72700.0","v":"2.30000","n":450}
        ]
        """
        let candles = try JSONDecoder().decode([HLCandle].self, from: json.data(using: .utf8)!)
        #expect(candles.count == 2)
        #expect(candles[0].t < candles[1].t)
    }
}

// MARK: - WebSocket Message Handling Tests

@Suite("WebSocket Message Handling")
struct WebSocketMessageTests {

    // Real allMids message format from Hyperliquid testnet WebSocket (verified via Python)
    static let allMidsMessage = """
    {"channel":"allMids","data":{"mids":{"BTC":"68460.0","ETH":"2534.0","SOL":"124.5"}}}
    """

    // Real candle message format from Hyperliquid testnet WebSocket
    static let candleMessage = """
    {"channel":"candle","data":{"t":1774486800000,"T":1774490399999,"s":"BTC","i":"1h","o":"72538.0","c":"72824.0","h":"73086.0","l":"71344.0","v":"1.50051","n":611}}
    """

    // Subscription response (not allMids or candle — should be ignored)
    static let subscriptionResponse = """
    {"channel":"subscriptionResponse","data":{"method":"subscribe","subscription":{"type":"allMids"}}}
    """

    @Test @MainActor func parsesAllMidsMessage() {
        let service = HyperliquidWebSocketService.shared
        let oldMids = service.mids

        service.handleMessage(WebSocketMessageTests.allMidsMessage)

        #expect(service.mids["BTC"] == "68460.0")
        #expect(service.mids["ETH"] == "2534.0")
        #expect(service.mids["SOL"] == "124.5")
        #expect(service.mids.count == 3)

        // Restore
        service.handleMessage("""
        {"channel":"allMids","data":{"mids":{}}}
        """)
    }

    @Test @MainActor func parsesCandle() {
        let service = HyperliquidWebSocketService.shared
        var received: [HLCandle] = []
        service.onCandleUpdate = { received.append($0) }

        service.handleMessage(WebSocketMessageTests.candleMessage)

        #expect(received.count == 1)
        #expect(received[0].s == "BTC")
        #expect(received[0].open == 72538.0)
        #expect(received[0].close == 72824.0)

        service.onCandleUpdate = nil
    }

    @Test @MainActor func candleCallbackFires() {
        let service = HyperliquidWebSocketService.shared
        var received: [HLCandle] = []
        service.onCandleUpdate = { received.append($0) }

        let msg1 = """
        {"channel":"candle","data":{"t":1774486800000,"T":1774490399999,"s":"BTC","i":"1h","o":"72538.0","c":"72824.0","h":"73086.0","l":"71344.0","v":"1.50051","n":611}}
        """
        let msg2 = """
        {"channel":"candle","data":{"t":1774490400000,"T":1774493999999,"s":"BTC","i":"1h","o":"72824.0","c":"73100.0","h":"73200.0","l":"72700.0","v":"2.30000","n":450}}
        """

        service.handleMessage(msg1)
        service.handleMessage(msg2)

        #expect(received.count == 2)
        #expect(received[0].t == 1774486800000)
        #expect(received[1].t == 1774490400000)

        service.onCandleUpdate = nil
    }

    @Test @MainActor func ignoresUnknownChannel() {
        let service = HyperliquidWebSocketService.shared
        let beforeMids = service.mids
        var candleReceived = false
        service.onCandleUpdate = { _ in candleReceived = true }

        service.handleMessage(WebSocketMessageTests.subscriptionResponse)

        #expect(service.mids == beforeMids)
        #expect(candleReceived == false)

        service.onCandleUpdate = nil
    }

    @Test @MainActor func ignoresInvalidJSON() {
        let service = HyperliquidWebSocketService.shared
        let beforeMids = service.mids

        service.handleMessage("not valid json at all")
        service.handleMessage("{}")
        service.handleMessage("{\"channel\":\"allMids\"}")  // missing data

        #expect(service.mids == beforeMids)
    }

    @Test @MainActor func ignoresMalformedCandle() {
        let service = HyperliquidWebSocketService.shared
        var candleReceived = false
        service.onCandleUpdate = { _ in candleReceived = true }

        let badCandle = """
        {"channel":"candle","data":{"t":123,"s":"BTC"}}
        """
        service.handleMessage(badCandle)
        #expect(candleReceived == false)

        service.onCandleUpdate = nil
    }
}

// MARK: - Candle Array Decoding

@Suite("Candle Array Decoding")
@MainActor struct CandleArrayDecodingTests {

    @Test func decodesArrayFromREST() throws {
        let json = """
        [
            {"t":1774486800000,"T":1774490399999,"s":"BTC","i":"1h","o":"72538.0","c":"72824.0","h":"73086.0","l":"71344.0","v":"1.50051","n":611},
            {"t":1774490400000,"T":1774493999999,"s":"BTC","i":"1h","o":"72824.0","c":"73100.0","h":"73200.0","l":"72700.0","v":"2.30000","n":450}
        ]
        """
        let candles = try JSONDecoder().decode([HLCandle].self, from: json.data(using: .utf8)!)

        #expect(candles.count == 2)
        #expect(candles[0].open == 72538.0)
        #expect(candles[1].open == 72824.0)
    }
}

// MARK: - HLAsset / HLAssetMeta Decoding

@Suite("HLAsset Decoding")
@MainActor struct HLAssetDecodingTests {

    static let metaJSON = """
    {"universe":[{"szDecimals":2,"name":"SOL","maxLeverage":10,"marginTableId":10},{"szDecimals":2,"name":"APT","maxLeverage":3,"marginTableId":3}]}
    """

    @Test func decodesMetaWithMaxLeverage() throws {
        let meta = try JSONDecoder().decode(HLAssetMeta.self, from: Self.metaJSON.data(using: .utf8)!)
        #expect(meta.universe.count == 2)
        #expect(meta.universe[0].name == "SOL")
        #expect(meta.universe[0].szDecimals == 2)
        #expect(meta.universe[0].maxLeverage == 10)
        #expect(meta.universe[1].name == "APT")
        #expect(meta.universe[1].maxLeverage == 3)
    }

    @Test func ignoresExtraFields() throws {
        let meta = try JSONDecoder().decode(HLAssetMeta.self, from: Self.metaJSON.data(using: .utf8)!)
        #expect(meta.universe.count == 2)
    }

    @Test func decodesOptionalFields() throws {
        let json = """
        {"universe":[{"szDecimals":5,"name":"BTC","maxLeverage":50,"onlyIsolated":true,"isDelisted":false}]}
        """
        let meta = try JSONDecoder().decode(HLAssetMeta.self, from: json.data(using: .utf8)!)
        #expect(meta.universe[0].onlyIsolated == true)
        #expect(meta.universe[0].isDelisted == false)
    }

    @Test func optionalFieldsDefaultToNil() throws {
        let json = """
        {"universe":[{"szDecimals":5,"name":"BTC","maxLeverage":50}]}
        """
        let meta = try JSONDecoder().decode(HLAssetMeta.self, from: json.data(using: .utf8)!)
        #expect(meta.universe[0].onlyIsolated == nil)
        #expect(meta.universe[0].isDelisted == nil)
    }
}

// MARK: - HLAssetCtx / HLMetaAndAssetCtxs Decoding

@Suite("HLAssetCtx Decoding")
@MainActor struct HLAssetCtxDecodingTests {

    static let ctxJSON = """
    {"funding":"0.0001660966","openInterest":"7466.18","prevDayPx":"79.651","dayNtlVlm":"505415.4002299999","premium":"0.002153904","oraclePx":"79.855","markPx":"80.036","midPx":"80.0595","impactPxs":["80.027","80.1786"],"dayBaseVlm":"6346.44"}
    """

    @Test func decodesAllFields() throws {
        let ctx = try JSONDecoder().decode(HLAssetCtx.self, from: Self.ctxJSON.data(using: .utf8)!)
        #expect(ctx.dayNtlVlm == "505415.4002299999")
        #expect(ctx.markPx == "80.036")
        #expect(ctx.midPx == "80.0595")
        #expect(ctx.prevDayPx == "79.651")
        #expect(ctx.funding == "0.0001660966")
        #expect(ctx.openInterest == "7466.18")
        #expect(ctx.oraclePx == "79.855")
        #expect(ctx.premium == "0.002153904")
        #expect(ctx.impactPxs?.count == 2)
    }

    @Test func decodesHeterogeneousArray() throws {
        let json = #"[{"universe":[{"szDecimals":2,"name":"SOL","maxLeverage":10}]},[{"funding":"0.0001","openInterest":"100","prevDayPx":"80","dayNtlVlm":"500","markPx":"81","midPx":"80.5","oraclePx":"80.2"}]]"#
        let result = try JSONDecoder().decode(HLMetaAndAssetCtxs.self, from: json.data(using: .utf8)!)
        #expect(result.meta.universe.count == 1)
        #expect(result.meta.universe[0].name == "SOL")
        #expect(result.assetCtxs.count == 1)
        #expect(result.assetCtxs[0].funding == Optional("0.0001"))
    }

    @Test func handlesNullMidPx() throws {
        let json = """
        {"funding":"0","openInterest":"0","prevDayPx":"0","dayNtlVlm":"0","markPx":"0","midPx":null,"oraclePx":"0"}
        """
        let ctx = try JSONDecoder().decode(HLAssetCtx.self, from: json.data(using: .utf8)!)
        #expect(ctx.midPx == nil)
    }
}

// MARK: - HLSpot Decoding

@Suite("HLSpot Decoding")
@MainActor struct HLSpotDecodingTests {

    static let tokenJSON = """
    {"name":"USDC","szDecimals":8,"weiDecimals":8,"index":0,"tokenId":"0xeb62eee3685fc4c43992febcd9e75443","isCanonical":true,"evmContract":{"address":"0x0b80659a4076e9e93c7dbe0f10675a16a3e5c206","evm_extra_wei_decimals":-2},"fullName":null,"deployerTradingFeeShare":"0.0"}
    """

    static let pairJSON = """
    {"tokens":[1,0],"name":"PURR/USDC","index":0,"isCanonical":true}
    """

    static let ctxJSON = """
    {"prevDayPx":"4.6483","dayNtlVlm":"1510.8823","markPx":"4.6714","midPx":"4.6483","circulatingSupply":"198730805.9340499938","coin":"PURR/USDC","totalSupply":"198733703.974999994","dayBaseVlm":"325.0"}
    """

    @Test func decodesSpotToken() throws {
        let token = try JSONDecoder().decode(HLSpotToken.self, from: Self.tokenJSON.data(using: .utf8)!)
        #expect(token.name == "USDC")
        #expect(token.index == 0)
        #expect(token.szDecimals == 8)
        #expect(token.weiDecimals == 8)
        #expect(token.tokenId == "0xeb62eee3685fc4c43992febcd9e75443")
        #expect(token.isCanonical == true)
        #expect(token.fullName == nil)
    }

    @Test func decodesSpotPair() throws {
        let pair = try JSONDecoder().decode(HLSpotPair.self, from: Self.pairJSON.data(using: .utf8)!)
        #expect(pair.name == "PURR/USDC")
        #expect(pair.tokens == [1, 0])
        #expect(pair.index == 0)
        #expect(pair.isCanonical == true)
    }

    @Test func decodesSpotCtxIgnoringExtraFields() throws {
        let ctx = try JSONDecoder().decode(HLSpotAssetCtx.self, from: Self.ctxJSON.data(using: .utf8)!)
        #expect(ctx.dayNtlVlm == "1510.8823")
        #expect(ctx.markPx == "4.6714")
        #expect(ctx.midPx == "4.6483")
        #expect(ctx.prevDayPx == "4.6483")
    }
}

// MARK: - HLPerpDex Decoding

@Suite("HLPerpDex Decoding")
@MainActor struct HLPerpDexDecodingTests {

    static let dexsJSON = """
    [null,{"name":"test","fullName":"test dex","deployer":"0x5e89b26d8d66da9888c835c9bfcc2aa51813e152","oracleUpdater":null,"feeRecipient":null,"assetToStreamingOiCap":[]},{"name":"unit","fullName":"unit dex","deployer":"0x888888880c61928866d8fcd1ac8655b7760b9f71"}]
    """

    @Test func decodesNullAndObjects() throws {
        let dexs = try JSONDecoder().decode([HLPerpDex?].self, from: Self.dexsJSON.data(using: .utf8)!)
        #expect(dexs.count == 3)
        #expect(dexs[0] == nil)
        #expect(dexs[1]?.name == "test")
        #expect(dexs[1]?.fullName == "test dex")
        #expect(dexs[2]?.name == "unit")
    }

    @Test func ignoresExtraFields() throws {
        let dexs = try JSONDecoder().decode([HLPerpDex?].self, from: Self.dexsJSON.data(using: .utf8)!)
        #expect(dexs[1]?.deployer == "0x5e89b26d8d66da9888c835c9bfcc2aa51813e152")
    }
}

// MARK: - HLFill Decoding

@Suite("HLFill Decoding")
@MainActor struct HLFillDecodingTests {

    static let minimalJSON = """
    {"coin":"BTC","side":"B","px":"94500.00","sz":"0.0500","time":1775200000000,"fee":"0.50","oid":12345}
    """

    static let fullJSON = """
    {"coin":"ETH","side":"A","px":"3200.50","sz":"1.2000","time":1775200000000,"fee":"-0.10","oid":67890,"tid":9876543,"closedPnl":"150.25","hash":"0xabc123","crossed":true,"dir":"Open Long","startPosition":"0.0","feeToken":"USDC","builderFee":"0.05"}
    """

    @Test func decodesMinimalFill() throws {
        let fill = try JSONDecoder().decode(HLFill.self, from: Self.minimalJSON.data(using: .utf8)!)
        #expect(fill.coin == "BTC")
        #expect(fill.isBuy == true)
        #expect(fill.price == 94500.0)
        #expect(fill.size == 0.05)
        #expect(fill.tid == nil)
        #expect(fill.closedPnl == nil)
    }

    @Test func decodesFullFill() throws {
        let fill = try JSONDecoder().decode(HLFill.self, from: Self.fullJSON.data(using: .utf8)!)
        #expect(fill.coin == "ETH")
        #expect(fill.isBuy == false)
        #expect(fill.tid == 9876543)
        #expect(fill.closedPnl == "150.25")
        #expect(fill.realizedPnl == 150.25)
        #expect(fill.hash == "0xabc123")
        #expect(fill.crossed == true)
        #expect(fill.dir == "Open Long")
        #expect(fill.feeToken == "USDC")
        #expect(fill.builderFee == "0.05")
    }

    @Test func idUsesTidWhenAvailable() throws {
        let fill = try JSONDecoder().decode(HLFill.self, from: Self.fullJSON.data(using: .utf8)!)
        #expect(fill.id == "9876543")
    }

    @Test func idFallsBackToOidTime() throws {
        let fill = try JSONDecoder().decode(HLFill.self, from: Self.minimalJSON.data(using: .utf8)!)
        #expect(fill.id == "12345-1775200000000")
    }
}

// MARK: - HLClearinghouseState Decoding

@Suite("HLClearinghouseState Decoding")
@MainActor struct HLClearinghouseStateDecodingTests {

    static let stateJSON = """
    {"marginSummary":{"accountValue":"10000.0","totalNtlPos":"5000.0","totalRawUsd":"5000.0","totalMarginUsed":"500.0"},"crossMarginSummary":{"accountValue":"10000.0","totalNtlPos":"5000.0","totalRawUsd":"5000.0","totalMarginUsed":"500.0"},"crossMaintenanceMarginUsed":"250.0","withdrawable":"9500.0","assetPositions":[{"type":"oneWay","position":{"coin":"BTC","szi":"0.05","entryPx":"94500.0","positionValue":"4725.0","unrealizedPnl":"31.18","returnOnEquity":"0.066","liquidationPx":"88000.0","marginUsed":"472.5","leverage":{"type":"cross","value":10,"rawUsd":"4725.0"},"maxLeverage":50,"cumFunding":{"allTime":"12.50","sinceChange":"3.20","sinceOpen":"5.10"}}}]}
    """

    @Test func decodesFullState() throws {
        let state = try JSONDecoder().decode(HLClearinghouseState.self, from: Self.stateJSON.data(using: .utf8)!)
        #expect(state.marginSummary.accountValue == "10000.0")
        #expect(state.crossMaintenanceMarginUsed == "250.0")
        #expect(state.withdrawable == "9500.0")
        #expect(state.assetPositions.count == 1)
    }

    @Test func decodesPositionNewFields() throws {
        let state = try JSONDecoder().decode(HLClearinghouseState.self, from: Self.stateJSON.data(using: .utf8)!)
        let pos = state.assetPositions[0].position
        #expect(pos.leverage.rawUsd == "4725.0")
        #expect(pos.maxLeverage == 50)
        #expect(pos.cumFunding?.allTime == "12.50")
        #expect(pos.cumFunding?.sinceChange == "3.20")
        #expect(pos.cumFunding?.sinceOpen == "5.10")
    }

    @Test func handlesMinimalPosition() throws {
        let json = """
        {"marginSummary":{"accountValue":"0","totalNtlPos":"0","totalRawUsd":"0","totalMarginUsed":"0"},"crossMarginSummary":{"accountValue":"0","totalNtlPos":"0","totalRawUsd":"0","totalMarginUsed":"0"},"withdrawable":"0","assetPositions":[{"type":"oneWay","position":{"coin":"ETH","szi":"0","positionValue":"0","unrealizedPnl":"0","returnOnEquity":"0","marginUsed":"0","leverage":{"type":"cross","value":5}}}]}
        """
        let state = try JSONDecoder().decode(HLClearinghouseState.self, from: json.data(using: .utf8)!)
        let pos = state.assetPositions[0].position
        #expect(pos.leverage.rawUsd == nil)
        #expect(pos.maxLeverage == nil)
        #expect(pos.cumFunding == nil)
        #expect(state.crossMaintenanceMarginUsed == nil)
    }
}

// MARK: - HLCandle Flexible Decode (String vs Number)

@Suite("HLCandle String Decode")
@MainActor struct HLCandleStringDecodeTests {

    @Test func decodesStringFields() throws {
        let json = """
        {"t":1775217600000,"T":1775221199999,"s":"BTC","i":"1h","o":"68654.0","c":"68375.0","h":"68846.0","l":"67986.0","v":"0.21984","n":114}
        """
        let candle = try JSONDecoder().decode(HLCandle.self, from: json.data(using: .utf8)!)
        #expect(candle.o == "68654.0")
        #expect(candle.c == "68375.0")
        #expect(candle.v == "0.21984")
        #expect(candle.open == 68654.0)
        #expect(candle.close == 68375.0)
        #expect(candle.volume == 0.21984)
    }
}

// MARK: - perpCategories Decoding

@Suite("PerpCategories Decoding")
@MainActor struct PerpCategoriesDecodingTests {

    @Test func decodesCategories() throws {
        let json = """
        [["birb:PENGU","test"],["flx:NVDA","stocks"],["xyz:GOLD","commodities"]]
        """
        let cats = try JSONDecoder().decode([[String]].self, from: json.data(using: .utf8)!)
        #expect(cats.count == 3)
        #expect(cats[0] == ["birb:PENGU", "test"])
        #expect(cats[1] == ["flx:NVDA", "stocks"])
        #expect(cats[2][1] == "commodities")
    }
}
