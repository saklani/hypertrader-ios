import Testing
import Foundation
import CryptoKit
@testable import hypertrader

// MARK: - Keccak256 Tests

struct Keccak256Tests {

    @Test func emptyInput() {
        let hash = Keccak.keccak256([UInt8]())
        let hex = Data(hash).toHexString()
        #expect(hex == "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470")
    }

    @Test func helloInput() {
        let hash = Keccak.keccak256(Array("hello".utf8))
        let hex = Data(hash).toHexString()
        #expect(hex == "1c8aff950685c2ed4bc3174f3472287b56d9517b9c948127319a09a7a36deac8")
    }

    @Test func testingInput() {
        let hash = Keccak.keccak256(Array("testing".utf8))
        let hex = Data(hash).toHexString()
        #expect(hex == "5f16f4c7f149ac4f9510d9cf8cf384038ad348b3bcdc01915f95de12df9d1b02")
    }

    @Test func dataOverloadMatchesByteOverload() {
        let input = Data("hypertrader".utf8)
        let fromData = Keccak.keccak256(input)
        let fromBytes = Data(Keccak.keccak256(Array(input)))
        #expect(fromData == fromBytes)
    }

    @Test func outputIs32Bytes() {
        let hash = Keccak.keccak256(Array("any input".utf8))
        #expect(hash.count == 32)
    }
}

// MARK: - MessagePack Encoder Tests

struct MsgPackTests {

    @Test func encodeBoolTrue() throws {
        let data = try MsgPackEncoder().encode(true)
        #expect(data == Data([0xc3]))
    }

    @Test func encodeBoolFalse() throws {
        let data = try MsgPackEncoder().encode(false)
        #expect(data == Data([0xc2]))
    }

    @Test func encodeSmallPositiveInt() throws {
        let data = try MsgPackEncoder().encode(42)
        #expect(data == Data([0x2a]))
    }

    @Test func encodeZero() throws {
        let data = try MsgPackEncoder().encode(0)
        #expect(data == Data([0x00]))
    }

    @Test func encodeString() throws {
        let data = try MsgPackEncoder().encode("hello")
        // fixstr: 0xa0 | 5 = 0xa5, then "hello" utf8
        #expect(data[0] == 0xa5)
        #expect(Data(data[1...]) == Data("hello".utf8))
    }

    @Test func encodeSimpleStruct() throws {
        struct TestStruct: Codable {
            let a: Int
            let b: Bool
        }
        let data = try MsgPackEncoder().encode(TestStruct(a: 1, b: true))
        // Should be a map with 2 entries
        #expect(data[0] == 0x82) // fixmap with 2 entries
        #expect(data.count > 2)
    }

    @Test func encodeArrayOfInts() throws {
        let data = try MsgPackEncoder().encode([1, 2, 3])
        // fixarray with 3 elements: 0x93
        #expect(data[0] == 0x93)
    }

    @Test func encodeConsistently() throws {
        let encoder = MsgPackEncoder()
        let value = ["key": "value"]
        let first = try encoder.encode(value)
        let second = try encoder.encode(value)
        #expect(first == second)
    }

    @Test func encodeOptionalNil() throws {
        struct WithOptional: Codable {
            let x: String?
        }
        let data = try MsgPackEncoder().encode(WithOptional(x: nil))
        // Map with 1 entry, value should be nil (0xc0)
        #expect(data.contains(0xc0))
    }

    @Test func encodeHLOrderAction() throws {
        let order = HLOrderWire(
            a: 0, b: true, p: "95000", s: "0.01", r: false,
            t: HLOrderTypeWire(limit: HLLimitWire(tif: "Gtc")), c: nil
        )
        let action = HLOrderAction(orders: [order], grouping: "na")
        let data = try MsgPackEncoder().encode(action)
        #expect(data.count > 0)
        // Re-encode should be identical
        let data2 = try MsgPackEncoder().encode(action)
        #expect(data == data2)
    }
}

// MARK: - EthSigner Tests

struct EthSignerTests {

    // Hardhat account #0
    static let knownPrivateKey = Data([
        0xac, 0x09, 0x74, 0xbe, 0xc3, 0x9a, 0x17, 0xe3,
        0x6b, 0xa4, 0xa6, 0xb4, 0xd2, 0x38, 0xff, 0x94,
        0x4b, 0xac, 0xb4, 0x78, 0xcb, 0xed, 0x5e, 0xfc,
        0xae, 0x78, 0x4d, 0x7b, 0xf4, 0xf2, 0xff, 0x80
    ])

    @Test func deriveKnownAddress() {
        let address = EthSigner.deriveAddress(from: Self.knownPrivateKey)
        // Hardhat account #0 address (case-insensitive comparison)
        #expect(address.lowercased() == "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266")
    }

    @Test func generatePrivateKeyIs32Bytes() {
        let key = EthSigner.generatePrivateKey()
        #expect(key.count == 32)
    }

    @Test func generatePrivateKeyIsUnique() {
        let key1 = EthSigner.generatePrivateKey()
        let key2 = EthSigner.generatePrivateKey()
        #expect(key1 != key2)
    }

    @Test func signatureFormat() throws {
        let typedData = EIP712Builder.phantomAgent(
            source: "b",
            connectionId: "0x" + String(repeating: "ab", count: 32)
        )
        let sig = try EthSigner.signTypedData(typedData, privateKey: Self.knownPrivateKey)
        #expect(sig.hasPrefix("0x"))
        #expect(sig.count == 132) // "0x" + 128 hex (r+s) + 2 hex (v)
    }

    @Test func signatureIsDeterministic() throws {
        let typedData = EIP712Builder.phantomAgent(
            source: "b",
            connectionId: "0x" + String(repeating: "cd", count: 32)
        )
        let sig1 = try EthSigner.signTypedData(typedData, privateKey: Self.knownPrivateKey)
        let sig2 = try EthSigner.signTypedData(typedData, privateKey: Self.knownPrivateKey)
        #expect(sig1 == sig2)
    }

    @Test func signatureVIs27Or28() throws {
        let typedData = EIP712Builder.phantomAgent(
            source: "a",
            connectionId: "0x" + String(repeating: "00", count: 32)
        )
        let sig = try EthSigner.signTypedData(typedData, privateKey: Self.knownPrivateKey)
        let vHex = String(sig.suffix(2))
        let v = Int(vHex, radix: 16)!
        #expect(v == 27 || v == 28)
    }

    @Test func hashTypedDataIs32Bytes() throws {
        let typedData = EIP712Builder.phantomAgent(
            source: "b",
            connectionId: "0x" + String(repeating: "ff", count: 32)
        )
        let hash = try EthSigner.hashTypedData(typedData)
        #expect(hash.count == 32)
    }
}

// MARK: - WCClient Crypto Tests

struct WCClientCryptoTests {

    @Test func encryptDecryptRoundtrip() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("hello walletconnect".utf8)

        let envelope = try WCClient.encrypt(data: plaintext, key: key)
        let decrypted = try WCClient.decrypt(envelope: envelope, key: key)

        #expect(decrypted == plaintext)
    }

    @Test func envelopeIsType0() throws {
        let key = SymmetricKey(size: .bits256)
        let envelope = try WCClient.encrypt(data: Data("test".utf8), key: key)

        let bytes = Data(base64Encoded: envelope)!
        #expect(bytes[0] == 0x00) // Type 0 envelope
    }

    @Test func decryptWithWrongKeyFails() throws {
        let key1 = SymmetricKey(size: .bits256)
        let key2 = SymmetricKey(size: .bits256)

        let envelope = try WCClient.encrypt(data: Data("secret".utf8), key: key1)
        #expect(throws: (any Error).self) {
            _ = try WCClient.decrypt(envelope: envelope, key: key2)
        }
    }

    @Test func topicFromKeyIsConsistent() {
        let key = SymmetricKey(size: .bits256)
        let topic1 = WCClient.topicFromKey(key)
        let topic2 = WCClient.topicFromKey(key)
        #expect(topic1 == topic2)
        #expect(topic1.count == 64) // SHA256 = 32 bytes = 64 hex chars
    }

    @Test func topicFromKeyMatchesSHA256() {
        let key = SymmetricKey(size: .bits256)
        let topic = WCClient.topicFromKey(key)

        // Verify against CryptoKit SHA256 directly
        let expected = key.withUnsafeBytes { bytes in
            SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        }
        #expect(topic == expected)
    }

    @Test func base64urlHasNoForbiddenChars() {
        // Data with bytes that produce +, /, = in standard base64
        let data = Data([0xfb, 0xff, 0xfe, 0x3e, 0x3f])
        let encoded = WCClient.base64url(data)
        #expect(!encoded.contains("+"))
        #expect(!encoded.contains("/"))
        #expect(!encoded.contains("="))
    }

    @Test func base58EmptyInput() {
        let result = WCClient.base58Encode([])
        #expect(result == "")
    }

    @Test func base58LeadingZeros() {
        // [0x00, 0x00, 0x01] → "112" (two leading '1's for zero bytes + '2' for value 1)
        let result = WCClient.base58Encode([0x00, 0x00, 0x01])
        #expect(result == "112")
    }

    @Test func base58KnownVector() {
        // "Hello World!" in base58
        let input = Array("Hello World!".utf8)
        let result = WCClient.base58Encode(input)
        #expect(result == "2NEpo7TZRRrLZSi2U")
    }

    @Test func deriveSymKeyIsSymmetric() throws {
        let keyA = Curve25519.KeyAgreement.PrivateKey()
        let keyB = Curve25519.KeyAgreement.PrivateKey()

        let symAB = try WCClient.deriveSymKey(privateKey: keyA, publicKey: keyB.publicKey)
        let symBA = try WCClient.deriveSymKey(privateKey: keyB, publicKey: keyA.publicKey)

        // Same shared secret → same derived key → same topic
        let topicAB = WCClient.topicFromKey(symAB)
        let topicBA = WCClient.topicFromKey(symBA)
        #expect(topicAB == topicBA)
    }

    @Test func relayJWTFormat() throws {
        let keyPair = Curve25519.Signing.PrivateKey()
        let jwt = try WCClient.generateRelayJWT(keyPair: keyPair)

        let parts = jwt.split(separator: ".")
        #expect(parts.count == 3) // header.payload.signature
    }

    @Test func generateIdIs19Digits() {
        let id = WCClient.generateId()
        let digits = String(id).count
        #expect(digits == 19)
    }
}

// MARK: - HyperliquidSigner Tests

struct HyperliquidSignerTests {

    @Test func parseValidSignature() {
        let r = String(repeating: "ab", count: 32)
        let s = String(repeating: "cd", count: 32)
        let hex = "0x" + r + s + "1b"

        let sig = HyperliquidSigner.parseSignature(hex)
        #expect(sig != nil)
        #expect(sig?.r == "0x" + r)
        #expect(sig?.s == "0x" + s)
        #expect(sig?.v == 27)
    }

    @Test func parseSignatureNormalizesV() {
        let r = String(repeating: "00", count: 32)
        let s = String(repeating: "00", count: 32)

        // v = 0x00 should normalize to 27
        let sig0 = HyperliquidSigner.parseSignature("0x" + r + s + "00")
        #expect(sig0?.v == 27)

        // v = 0x01 should normalize to 28
        let sig1 = HyperliquidSigner.parseSignature("0x" + r + s + "01")
        #expect(sig1?.v == 28)
    }

    @Test func parseInvalidSignatureReturnsNil() {
        #expect(HyperliquidSigner.parseSignature("0xtooshort") == nil)
        #expect(HyperliquidSigner.parseSignature("") == nil)
    }

    @Test func buildApproveAgentTypedData() {
        let typedData = HyperliquidSigner.buildApproveAgentTypedData(
            agentAddress: "0x1234567890abcdef1234567890abcdef12345678",
            nonce: 1700000000000,
            isTestnet: true
        )
        #expect(typedData.primaryType == "HyperliquidTransaction:ApproveAgent")

        // Domain should have testnet chainId (421614)
        if case .int(let chainId) = typedData.domain["chainId"] {
            #expect(chainId == 421614)
        } else {
            Issue.record("chainId missing or wrong type")
        }

        // Message should contain the agent address
        if case .string(let addr) = typedData.message["agentAddress"] {
            #expect(addr == "0x1234567890abcdef1234567890abcdef12345678")
        } else {
            Issue.record("agentAddress missing")
        }
    }

    @Test func signOrderProducesValidSignature() throws {
        let key = EthSigner.generatePrivateKey()
        let order = HLOrderWire(
            a: 0, b: true, p: "95000", s: "0.01", r: false,
            t: HLOrderTypeWire(limit: HLLimitWire(tif: "Gtc")), c: nil
        )
        let (sig, nonce) = try HyperliquidSigner.signOrder(
            orders: [order], agentPrivateKey: key
        )
        #expect(sig.r.hasPrefix("0x"))
        #expect(sig.s.hasPrefix("0x"))
        #expect(sig.v == 27 || sig.v == 28)
        #expect(nonce > 1700000000000) // sanity: after year 2023
    }

    @Test func generateNonceIsRecentTimestamp() {
        let nonce = HyperliquidSigner.generateNonce()
        let now = UInt64(Date().timeIntervalSince1970 * 1000)
        #expect(nonce <= now + 1000) // within 1 second
        #expect(nonce >= now - 1000)
    }
}

// MARK: - EIP712Types Tests

struct EIP712TypesTests {

    @Test func toJSONStringProducesValidJSON() {
        let typedData = EIP712Builder.phantomAgent(
            source: "b",
            connectionId: "0x" + String(repeating: "00", count: 32)
        )
        let json = typedData.toJSONString()
        #expect(json != nil)

        // Should parse back as valid JSON
        let parsed = try? JSONSerialization.jsonObject(with: Data(json!.utf8))
        #expect(parsed != nil)
    }

    @Test func anyJSONStringValue() {
        let val = AnyJSON.string("hello")
        #expect(val.stringValue == "hello")
        #expect(val.intValue == nil)
    }

    @Test func anyJSONIntValue() {
        let val = AnyJSON.int(42)
        #expect(val.intValue == 42)
        #expect(val.stringValue == nil)
    }

    @Test func anyJSONUint64Value() {
        let val = AnyJSON.uint64(1700000000000)
        #expect(val.uint64Value == 1700000000000)
    }

    @Test func anyJSONNullHasNoValues() {
        let val = AnyJSON.null
        #expect(val.stringValue == nil)
        #expect(val.intValue == nil)
        #expect(val.uint64Value == nil)
    }

    @Test func phantomAgentBuilder() {
        let td = EIP712Builder.phantomAgent(source: "b", connectionId: "0xabc")
        #expect(td.primaryType == "Agent")
        #expect(td.types["Agent"] != nil)
        #expect(td.types["Agent"]?.count == 2)
    }

    @Test func approveAgentBuilderTestnet() {
        let td = EIP712Builder.approveAgent(
            agentAddress: "0xabc",
            nonce: 123,
            isTestnet: true
        )
        #expect(td.primaryType == "HyperliquidTransaction:ApproveAgent")
        if case .string(let chain) = td.message["hyperliquidChain"] {
            #expect(chain == "Testnet")
        }
    }

    @Test func approveAgentBuilderMainnet() {
        let td = EIP712Builder.approveAgent(
            agentAddress: "0xabc",
            nonce: 123,
            isTestnet: false
        )
        if case .string(let chain) = td.message["hyperliquidChain"] {
            #expect(chain == "Mainnet")
        }
        if case .int(let chainId) = td.domain["chainId"] {
            #expect(chainId == 42161)
        }
    }
}
