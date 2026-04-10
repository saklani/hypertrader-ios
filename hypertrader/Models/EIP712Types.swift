import Foundation

// MARK: - EIP-712 Typed Data (for JSON serialization to WalletConnect + local hashing)

nonisolated struct EIP712TypedData: Codable, Sendable {
    let types: [String: [EIP712Field]]
    let primaryType: String
    let domain: [String: AnyJSON]
    let message: [String: AnyJSON]

    func toJSONString() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

nonisolated struct EIP712Field: Codable, Equatable, Sendable {
    let name: String
    let type: String
}

// MARK: - Hyperliquid Domains

nonisolated enum HLDomains {
    /// L1 action signing (phantom agent)
    static func exchange() -> [String: AnyJSON] {
        [
            "name": .string("Exchange"),
            "version": .string("1"),
            "chainId": .int(1337),
            "verifyingContract": .string("0x0000000000000000000000000000000000000000")
        ]
    }

    /// User signed action (approveAgent, etc.)
    static func userSigned() -> [String: AnyJSON] {
        [
            "name": .string("HyperliquidSignTransaction"),
            "version": .string("1"),
            "chainId": .int(HyperliquidConfig.userSignedChainId),
            "verifyingContract": .string("0x0000000000000000000000000000000000000000")
        ]
    }
}

// MARK: - EIP-712 Type Definitions

nonisolated enum HLEIPTypes {
    static let eip712Domain: [EIP712Field] = [
        EIP712Field(name: "name", type: "string"),
        EIP712Field(name: "version", type: "string"),
        EIP712Field(name: "chainId", type: "uint256"),
        EIP712Field(name: "verifyingContract", type: "address")
    ]

    static let agent: [EIP712Field] = [
        EIP712Field(name: "source", type: "string"),
        EIP712Field(name: "connectionId", type: "bytes32")
    ]

    static let approveAgent: [EIP712Field] = [
        EIP712Field(name: "hyperliquidChain", type: "string"),
        EIP712Field(name: "agentAddress", type: "address"),
        EIP712Field(name: "agentName", type: "string"),
        EIP712Field(name: "nonce", type: "uint64")
    ]
}

// MARK: - Builders

nonisolated enum EIP712Builder {
    /// Phantom agent typed data for L1 action signing
    static func phantomAgent(source: String, connectionId: String) -> EIP712TypedData {
        EIP712TypedData(
            types: [
                "EIP712Domain": HLEIPTypes.eip712Domain,
                "Agent": HLEIPTypes.agent
            ],
            primaryType: "Agent",
            domain: HLDomains.exchange(),
            message: [
                "source": .string(source),
                "connectionId": .string(connectionId)
            ]
        )
    }

    /// ApproveAgent typed data (signed by master wallet via WalletConnect)
    static func approveAgent(
        agentAddress: String,
        agentName: String = "hypertrader",
        nonce: UInt64
    ) -> EIP712TypedData {
        EIP712TypedData(
            types: [
                "EIP712Domain": HLEIPTypes.eip712Domain,
                "HyperliquidTransaction:ApproveAgent": HLEIPTypes.approveAgent
            ],
            primaryType: "HyperliquidTransaction:ApproveAgent",
            domain: HLDomains.userSigned(),
            message: [
                "hyperliquidChain": .string(HyperliquidConfig.chainName),
                "agentAddress": .string(agentAddress),
                "agentName": .string(agentName),
                "nonce": .uint64(nonce)
            ]
        )
    }
}

// MARK: - AnyJSON (lightweight JSON value wrapper)

nonisolated enum AnyJSON: Codable, Equatable {
    case string(String)
    case int(Int)
    case uint64(UInt64)
    case bool(Bool)
    case null

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .uint64(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(String.self) { self = .string(v) }
        else if let v = try? container.decode(Int.self) { self = .int(v) }
        else if let v = try? container.decode(Bool.self) { self = .bool(v) }
        else { self = .null }
    }

    /// Raw value for EIP-712 encoding
    var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }

    var intValue: Int? {
        if case .int(let v) = self { return v }
        return nil
    }

    var uint64Value: UInt64? {
        if case .uint64(let v) = self { return v }
        return nil
    }
}
