import Foundation

/// Constructs Hyperliquid action payloads and signs them locally with the agent key.
enum HyperliquidSigner {

    // MARK: - Sign Order (full flow: action → msgpack → hash → EIP-712 → sign)

    /// Build and sign an order action with the local agent key.
    /// Returns the signature and nonce needed for the exchange request.
    static func signOrder(
        orders: [HLOrderWire],
        grouping: String = "na",
        builder: HLBuilderWire? = nil,
        agentPrivateKey: Data,
        isTestnet: Bool = true
    ) throws -> (signature: HLSignature, nonce: UInt64) {
        let action = HLOrderAction(orders: orders, grouping: grouping, builder: builder)
        return try signL1Action(action: action, agentPrivateKey: agentPrivateKey, isTestnet: isTestnet)
    }

    /// Build and sign a cancel action with the local agent key.
    static func signCancel(
        cancels: [HLCancelWire],
        agentPrivateKey: Data,
        isTestnet: Bool = true
    ) throws -> (signature: HLSignature, nonce: UInt64) {
        let action = HLCancelAction(cancels: cancels)
        return try signL1Action(action: action, agentPrivateKey: agentPrivateKey, isTestnet: isTestnet)
    }

    // MARK: - ApproveAgent (typed data only — signed by master wallet via WalletConnect)

    /// Build the approveAgent typed data for the master wallet to sign.
    static func buildApproveAgentTypedData(
        agentAddress: String,
        agentName: String = "hypertrader",
        nonce: UInt64,
        isTestnet: Bool = true
    ) -> EIP712TypedData {
        EIP712Builder.approveAgent(
            agentAddress: agentAddress,
            agentName: agentName,
            nonce: nonce,
            isTestnet: isTestnet
        )
    }

    /// Generate a nonce (millisecond timestamp)
    static func generateNonce() -> UInt64 {
        UInt64(Date().timeIntervalSince1970 * 1000)
    }

    // MARK: - Core L1 Signing Flow

    /// action → MessagePack → append nonce → Keccak256 → phantom agent → EIP-712 → sign
    private static func signL1Action<T: Encodable>(
        action: T,
        agentPrivateKey: Data,
        isTestnet: Bool
    ) throws -> (signature: HLSignature, nonce: UInt64) {
        let nonce = generateNonce()

        // 1. MessagePack serialize the action
        let encoder = MsgPackEncoder()
        let msgpackData = try encoder.encode(action)

        // 2. Build hash input: msgpack_bytes + nonce(u64 BE) + vault(0x00)
        var hashInput = Data(msgpackData)
        withUnsafeBytes(of: nonce.bigEndian) { bytes in
            hashInput.append(contentsOf: bytes)
        }
        hashInput.append(0x00) // no vault address

        // 3. Keccak256 hash → actionHash
        let actionHash = Keccak.keccak256(Array(hashInput))
        let actionHashHex = "0x" + Data(actionHash).toHexString()

        // 4. Build phantom agent EIP-712 typed data
        let source = isTestnet ? "b" : "a"
        let typedData = EIP712Builder.phantomAgent(source: source, connectionId: actionHashHex)

        // 5. Sign locally with agent key
        let signatureHex = try EthSigner.signTypedData(typedData, privateKey: agentPrivateKey)

        guard let signature = parseSignature(signatureHex) else {
            throw HLError.signingFailed("Failed to parse signature")
        }

        return (signature, nonce)
    }

    // MARK: - Signature Parsing

    /// Parse "0x" + r(64 hex) + s(64 hex) + v(2 hex) into HLSignature
    static func parseSignature(_ signatureHex: String) -> HLSignature? {
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
}
