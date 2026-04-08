import Foundation

/// Constructs Hyperliquid action payloads and signs them locally with the agent key.
/// Includes EIP-712 typed data encoding for Hyperliquid's L1 actions.
nonisolated enum HyperliquidSigner {

    // MARK: - Sign L1 Action

    /// action → MessagePack → append nonce → Keccak256 → phantom agent → EIP-712 → sign.
    /// Runs entirely off the main thread via `Task.detached`.
    static func sign<T: Encodable & Sendable>(
        privateKey: Data,
        action: T
    ) async throws -> (signature: HLSignature, nonce: UInt64) {
        try await Task.detached {
            let nonce = generateNonce()

            // 1. MessagePack serialize the action
            let messagePackData = try MessagePackEncoder().encode(action)

            // 2. Build hash input: msgpack_bytes + nonce(u64 BE) + vault(0x00)
            var hashInput = Data(messagePackData)
            withUnsafeBytes(of: nonce.bigEndian) { bytes in
                hashInput.append(contentsOf: bytes)
            }
            hashInput.append(0x00)

            // 3. Keccak256 hash → actionHash
            let actionHash = Keccak.keccak256(Array(hashInput))
            let actionHashHex = "0x" + Data(actionHash).toHexString()

            // 4. Build phantom agent EIP-712 typed data
            let typedData = EIP712Builder.phantomAgent(source: HyperliquidConfig.phantomAgentSource, connectionId: actionHashHex)

            // 5. EIP-712 hash: keccak256(0x19 0x01 || domainSeparator || messageHash)
            let digest = try hashEIP712(typedData)

            // 6. Sign with agent key
            let signatureHex = try EthereumSigner.sign(privateKey: privateKey, digest: digest)

            guard let signature = parse(signature: signatureHex) else {
                throw HLError.signingFailed("Failed to parse signature")
            }

            return (signature, nonce)
        }.value
    }

    // MARK: - Nonce

    /// Millisecond timestamp. Per HL docs: "Recommended to use the current timestamp in milliseconds."
    static func generateNonce() -> UInt64 {
        UInt64(Date().timeIntervalSince1970 * 1000)
    }

    // MARK: - Signature Parsing

    static func parse(signature signatureHex: String) -> HLSignature? {
        var hex = signatureHex
        if hex.hasPrefix("0x") {
            hex = String(hex.dropFirst(2))
        }

        guard hex.count == 130 else { return nil }

        let r = "0x" + String(hex.prefix(64))
        let s = "0x" + String(hex.dropFirst(64).prefix(64))
        let vHex = String(hex.suffix(2))
        guard var v = Int(vHex, radix: 16) else { return nil }

        if v < 27 { v += 27 }

        return HLSignature(r: r, s: s, v: v)
    }

    // MARK: - EIP-712 Hashing

    /// Compute full EIP-712 digest: keccak256(0x19 0x01 || domainSeparator || messageHash)
    static func hashEIP712(_ typedData: EIP712TypedData) throws -> Data {
        let domainSeparator = try hashStruct(
            typeName: "EIP712Domain",
            data: typedData.domain,
            types: typedData.types
        )
        let messageHash = try hashStruct(
            typeName: typedData.primaryType,
            data: typedData.message,
            types: typedData.types
        )
        var input = Data([0x19, 0x01])
        input.append(domainSeparator)
        input.append(messageHash)
        return Keccak.keccak256(input)
    }

    /// Hash a single EIP-712 struct: keccak256(typeHash || encodedFields)
    private static func hashStruct(
        typeName: String,
        data: [String: AnyJSON],
        types: [String: [EIP712Field]]
    ) throws -> Data {
        guard let fields = types[typeName] else {
            throw HLError.encodingFailed("Unknown type: \(typeName)")
        }

        let typeString = encodeType(typeName: typeName, types: types)
        let typeHash = Keccak.keccak256(Array(typeString.utf8))

        var encoded = Data(typeHash)
        for field in fields {
            let value = data[field.name] ?? .null
            let encodedValue = try encodeField(type: field.type, value: value, types: types)
            encoded.append(encodedValue)
        }

        return Keccak.keccak256(encoded)
    }

    // MARK: - EIP-712 Encoding

    private static func encodeType(
        typeName: String,
        types: [String: [EIP712Field]]
    ) -> String {
        guard let fields = types[typeName] else { return "" }
        let params = fields.map { "\($0.type) \($0.name)" }.joined(separator: ",")
        return "\(typeName)(\(params))"
    }

    private static func encodeField(
        type: String,
        value: AnyJSON,
        types: [String: [EIP712Field]]
    ) throws -> Data {
        switch type {
        case "string":
            guard let str = value.stringValue else {
                return Data(repeating: 0, count: 32)
            }
            return Data(Keccak.keccak256(Array(str.utf8)))

        case "bytes32":
            guard let hex = value.stringValue else {
                return Data(repeating: 0, count: 32)
            }
            return hexToBytes32(hex)

        case "address":
            guard let hex = value.stringValue else {
                return Data(repeating: 0, count: 32)
            }
            return hexToBytes32(hex)

        case "uint256", "uint64":
            if let intVal = value.intValue {
                return uint256ToBytes32(UInt64(intVal))
            }
            if let u64Val = value.uint64Value {
                return uint256ToBytes32(u64Val)
            }
            return Data(repeating: 0, count: 32)

        case "bool":
            var data = Data(repeating: 0, count: 32)
            if case .bool(let b) = value, b {
                data[31] = 1
            }
            return data

        default:
            if types[type] != nil {
                throw HLError.encodingFailed("Nested struct encoding not implemented: \(type)")
            }
            throw HLError.encodingFailed("Unknown EIP-712 field type: \(type)")
        }
    }

    // MARK: - Byte Helpers

    private static func hexToBytes32(_ hex: String) -> Data {
        var cleanHex = hex
        if cleanHex.hasPrefix("0x") {
            cleanHex = String(cleanHex.dropFirst(2))
        }
        cleanHex = String(repeating: "0", count: max(0, 64 - cleanHex.count)) + cleanHex
        cleanHex = String(cleanHex.suffix(64))

        var data = Data()
        var index = cleanHex.startIndex
        for _ in 0..<32 {
            let nextIndex = cleanHex.index(index, offsetBy: 2)
            let byteStr = cleanHex[index..<nextIndex]
            if let byte = UInt8(byteStr, radix: 16) {
                data.append(byte)
            }
            index = nextIndex
        }
        return data
    }

    private static func uint256ToBytes32(_ value: UInt64) -> Data {
        var data = Data(repeating: 0, count: 24)
        var bigEndian = value.bigEndian
        data.append(Data(bytes: &bigEndian, count: 8))
        return data
    }
}
