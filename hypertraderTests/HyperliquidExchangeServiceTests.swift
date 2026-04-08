import Testing
import Foundation
@testable import hypertrader

// Reference values from Python SDK (debug_hl_exchange.py)
// Private key: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
// Address: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

// MARK: - OrderInput Tests

@Suite("OrderInput")
@MainActor struct OrderInputTests {

    @Test func effectivePriceMarketBuy() {
        let input = OrderInput(
            asset: HLAsset(name: "BTC", szDecimals: 5, maxLeverage: 50, onlyIsolated: nil, isDelisted: nil),
            assetIndex: 3, isBuy: true, size: "0.01",
            price: 95000, slippage: 0.01, isMarket: true, reduceOnly: false
        )
        #expect(input.effectivePrice == 95000 * 1.01) // 95950
    }

    @Test func effectivePriceMarketSell() {
        let input = OrderInput(
            asset: HLAsset(name: "BTC", szDecimals: 5, maxLeverage: 50, onlyIsolated: nil, isDelisted: nil),
            assetIndex: 3, isBuy: false, size: "0.01",
            price: 95000, slippage: 0.01, isMarket: true, reduceOnly: false
        )
        #expect(input.effectivePrice == 95000 * 0.99) // 94050
    }

    @Test func effectivePriceLimitIgnoresSlippage() {
        let input = OrderInput(
            asset: HLAsset(name: "BTC", szDecimals: 5, maxLeverage: 50, onlyIsolated: nil, isDelisted: nil),
            assetIndex: 3, isBuy: true, size: "0.01",
            price: 95000, slippage: 0.05, isMarket: false, reduceOnly: false
        )
        #expect(input.effectivePrice == 95000) // exact price, no slippage
    }
}

// MARK: - Wire Conversion Tests

@Suite("Wire Conversion")
@MainActor struct WireConversionTests {

    let service = HyperliquidExchangeService.shared

    @Test func marketBuyWire() {
        let input = OrderInput(
            asset: HLAsset(name: "BTC", szDecimals: 5, maxLeverage: 50, onlyIsolated: nil, isDelisted: nil),
            assetIndex: 3, isBuy: true, size: "0.01",
            price: 95000, slippage: 0.01, isMarket: true, reduceOnly: false
        )
        let wire = service.toWire(input)
        #expect(wire.a == 3)
        #expect(wire.b == true)
        #expect(wire.s == "0.01")
        #expect(wire.r == false)
        #expect(wire.t.limit?.tif == "Ioc") // market = IOC
        #expect(wire.c == nil)
    }

    @Test func limitSellWire() {
        let input = OrderInput(
            asset: HLAsset(name: "ETH", szDecimals: 4, maxLeverage: 50, onlyIsolated: nil, isDelisted: nil),
            assetIndex: 4, isBuy: false, size: "1.5",
            price: 3200, slippage: 0, isMarket: false, reduceOnly: false
        )
        let wire = service.toWire(input)
        #expect(wire.a == 4)
        #expect(wire.b == false)
        #expect(wire.p == "3200")
        #expect(wire.s == "1.5")
        #expect(wire.t.limit?.tif == "Gtc") // limit = GTC
    }

    @Test func wireStripsTrailingZeros() {
        let input = OrderInput(
            asset: HLAsset(name: "BTC", szDecimals: 5, maxLeverage: 50, onlyIsolated: nil, isDelisted: nil),
            assetIndex: 3, isBuy: true, size: "0.0100",
            price: 95000.00, slippage: 0, isMarket: false, reduceOnly: false
        )
        let wire = service.toWire(input)
        #expect(wire.p == "95000") // not "95000.0" or "95000.00"
        #expect(wire.s == "0.01") // not "0.0100"
    }

    @Test func reduceOnlyPassedThrough() {
        let input = OrderInput(
            asset: HLAsset(name: "BTC", szDecimals: 5, maxLeverage: 50, onlyIsolated: nil, isDelisted: nil),
            assetIndex: 3, isBuy: true, size: "0.01",
            price: 95000, slippage: 0, isMarket: true, reduceOnly: true
        )
        let wire = service.toWire(input)
        #expect(wire.r == true)
    }
}

// MARK: - encodeOrderType Tests

@Suite("Order Type Encoding")
@MainActor struct OrderTypeEncodingTests {

    let service = HyperliquidExchangeService.shared

    @Test func encodesLimit() {
        let t = HLOrderTypeWire(limit: HLLimitWire(tif: "Gtc"))
        let encoded = service.encodeOrderType(t)
        let limit = encoded["limit"] as? [String: String]
        #expect(limit?["tif"] == "Gtc")
    }

    @Test func encodesTrigger() {
        let t = HLOrderTypeWire(trigger: HLTriggerWire(isMarket: true, triggerPx: "95000", tpsl: "tp"))
        let encoded = service.encodeOrderType(t)
        let trigger = encoded["trigger"] as? [String: Any]
        #expect(trigger?["isMarket"] as? Bool == true)
        #expect(trigger?["triggerPx"] as? String == "95000")
        #expect(trigger?["tpsl"] as? String == "tp")
    }
}

// MARK: - MessagePack Encoding (compared to Python SDK)

@Suite("MessagePack Reference")
@MainActor struct MessagePackReferenceTests {

    // Python SDK output for same order (no builder):
    // 83a474797065a56f72646572a66f72646572739187a16103a162c3a170a53935303030a173a4302e3031a172c2a17481a56c696d697481a3746966a3477463a163c0a867726f7570696e67a26e61
    static let expectedOrderMsgpackHex = "83a474797065a56f72646572a66f72646572739187a16103a162c3a170a53935303030a173a4302e3031a172c2a17481a56c696d697481a3746966a3477463a163c0a867726f7570696e67a26e61"

    // Python SDK output for cancel:
    // 82a474797065a663616e63656ca763616e63656c739182a16103a16fcd3039
    static let expectedCancelMsgpackHex = "82a474797065a663616e63656ca763616e63656c739182a16103a16fcd3039"

    @Test func orderMessagePackMatchesPythonSDK() throws {
        let order = HLOrderWire(a: 3, b: true, p: "95000", s: "0.01", r: false,
                                t: HLOrderTypeWire(limit: HLLimitWire(tif: "Gtc")), c: nil)
        let action = HLOrderAction(orders: [order], grouping: "na", builder: nil)
        let data = try MessagePackEncoder().encode(action)
        let hex = Data(data).toHexString()
        #expect(hex == Self.expectedOrderMsgpackHex)
    }

    @Test func cancelMessagePackMatchesPythonSDK() throws {
        let action = HLCancelAction(cancels: [HLCancelWire(a: 3, o: 12345)])
        let data = try MessagePackEncoder().encode(action)
        let hex = Data(data).toHexString()
        #expect(hex == Self.expectedCancelMsgpackHex)
    }
}

// MARK: - Action Hash (compared to Python SDK)

@Suite("Action Hash Reference")
@MainActor struct ActionHashReferenceTests {

    // Python SDK: keccak256(msgpack + nonce_be + 0x00)
    // Order action hash: 0x4353124ba26dd234471b41672ee4e5758d1e7bc6bdac999f57039e84c97667ea
    static let expectedOrderActionHash = "4353124ba26dd234471b41672ee4e5758d1e7bc6bdac999f57039e84c97667ea"
    static let fixedNonce: UInt64 = 1700000000000

    @Test func orderActionHashMatchesPythonSDK() throws {
        let order = HLOrderWire(a: 3, b: true, p: "95000", s: "0.01", r: false,
                                t: HLOrderTypeWire(limit: HLLimitWire(tif: "Gtc")), c: nil)
        let action = HLOrderAction(orders: [order], grouping: "na", builder: nil)

        let msgpackData = try MessagePackEncoder().encode(action)
        var hashInput = Data(msgpackData)
        withUnsafeBytes(of: Self.fixedNonce.bigEndian) { bytes in
            hashInput.append(contentsOf: bytes)
        }
        hashInput.append(0x00)

        let hash = Keccak.keccak256(Array(hashInput))
        let hex = Data(hash).toHexString()
        #expect(hex == Self.expectedOrderActionHash)
    }

    // Cancel action hash: 0x450315d7f6807dcb9fcc4ac6d68b5bf3f8fa33cdaa7df67b643f0c51b813f0e0
    static let expectedCancelActionHash = "450315d7f6807dcb9fcc4ac6d68b5bf3f8fa33cdaa7df67b643f0c51b813f0e0"

    @Test func cancelActionHashMatchesPythonSDK() throws {
        let action = HLCancelAction(cancels: [HLCancelWire(a: 3, o: 12345)])

        let msgpackData = try MessagePackEncoder().encode(action)
        var hashInput = Data(msgpackData)
        withUnsafeBytes(of: Self.fixedNonce.bigEndian) { bytes in
            hashInput.append(contentsOf: bytes)
        }
        hashInput.append(0x00)

        let hash = Keccak.keccak256(Array(hashInput))
        let hex = Data(hash).toHexString()
        #expect(hex == Self.expectedCancelActionHash)
    }
}

// MARK: - Full Signature (compared to Python SDK)

@Suite("Signature Reference")
@MainActor struct SignatureReferenceTests {

    // Hardhat account #0
    static let knownPrivateKey = Data([
        0xac, 0x09, 0x74, 0xbe, 0xc3, 0x9a, 0x17, 0xe3,
        0x6b, 0xa4, 0xa6, 0xb4, 0xd2, 0x38, 0xff, 0x94,
        0x4b, 0xac, 0xb4, 0x78, 0xcb, 0xed, 0x5e, 0xfc,
        0xae, 0x78, 0x4d, 0x7b, 0xf4, 0xf2, 0xff, 0x80
    ])

    // Python SDK signature for order with nonce 1700000000000, expires_after=None:
    // r: 0x461f4796ecc8033f3b3f5cd1011c1a4db4760c429a464e3585105551de4d94db
    // s: 0x452ca911fcd5ba2255eb049879fa057434262772461155c5c5213293bbc83aff
    // v: 28

    @Test func orderSignatureMatchesPythonSDK() throws {
        let order = HLOrderWire(a: 3, b: true, p: "95000", s: "0.01", r: false,
                                t: HLOrderTypeWire(limit: HLLimitWire(tif: "Gtc")), c: nil)
        let action = HLOrderAction(orders: [order], grouping: "na", builder: nil)

        // Replicate the signing chain with fixed nonce
        let nonce: UInt64 = 1700000000000
        let msgpackData = try MessagePackEncoder().encode(action)
        var hashInput = Data(msgpackData)
        withUnsafeBytes(of: nonce.bigEndian) { bytes in
            hashInput.append(contentsOf: bytes)
        }
        hashInput.append(0x00)

        let actionHash = Keccak.keccak256(Array(hashInput))
        let actionHashHex = "0x" + Data(actionHash).toHexString()

        let typedData = EIP712Builder.phantomAgent(source: "b", connectionId: actionHashHex)
        let digest = try HyperliquidSigner.hashEIP712(typedData)
        let signatureHex = try EthereumSigner.sign(privateKey: Self.knownPrivateKey, digest: digest)

        let sig = HyperliquidSigner.parse(signature: signatureHex)
        #expect(sig != nil)
        #expect(sig?.r == "0x461f4796ecc8033f3b3f5cd1011c1a4db4760c429a464e3585105551de4d94db")
        #expect(sig?.s == "0x452ca911fcd5ba2255eb049879fa057434262772461155c5c5213293bbc83aff")
        #expect(sig?.v == 28)
    }

    // Python SDK cancel signature with nonce 1700000000000, expires_after=None:
    // r: 0xac9e789c4db0da12eec04f40f883d2e2bba750c68242beca13ce4ffa6e534da5
    // s: 0x34e9970d1280764736a6290a4efcd76b7db36999af1d4634c145a264a2dbf596
    // v: 28

    @Test func cancelSignatureMatchesPythonSDK() throws {
        let action = HLCancelAction(cancels: [HLCancelWire(a: 3, o: 12345)])

        let nonce: UInt64 = 1700000000000
        let msgpackData = try MessagePackEncoder().encode(action)
        var hashInput = Data(msgpackData)
        withUnsafeBytes(of: nonce.bigEndian) { bytes in
            hashInput.append(contentsOf: bytes)
        }
        hashInput.append(0x00)

        let actionHash = Keccak.keccak256(Array(hashInput))
        let actionHashHex = "0x" + Data(actionHash).toHexString()

        let typedData = EIP712Builder.phantomAgent(source: "b", connectionId: actionHashHex)
        let digest = try HyperliquidSigner.hashEIP712(typedData)
        let signatureHex = try EthereumSigner.sign(privateKey: Self.knownPrivateKey, digest: digest)

        let sig = HyperliquidSigner.parse(signature: signatureHex)
        #expect(sig != nil)
        #expect(sig?.r == "0xac9e789c4db0da12eec04f40f883d2e2bba750c68242beca13ce4ffa6e534da5")
        #expect(sig?.s == "0x34e9970d1280764736a6290a4efcd76b7db36999af1d4634c145a264a2dbf596")
        #expect(sig?.v == 28)
    }
}

// MARK: - formatPrice Tests

@Suite("Format Price")
@MainActor struct FormatPriceTests {

    @Test func stripsTrailingZeros() {
        #expect(formatPrice("95000.00") == "95000")
        #expect(formatPrice("0.0100") == "0.01")
        #expect(formatPrice("3200.50") == "3200.5")
    }

    @Test func preservesNecessaryDecimals() {
        #expect(formatPrice("0.001") == "0.001")
        #expect(formatPrice("95000") == "95000")
    }

    @Test func handlesInvalidInput() {
        #expect(formatPrice("notanumber") == "notanumber")
        #expect(formatPrice("") == "")
    }
}
