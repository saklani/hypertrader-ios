import Foundation

/// Central network configuration. Flip `isMainnet` to switch all services.
nonisolated enum HyperliquidConfig {

    // MARK: - URLs

    static let infoURL = "https://api.hyperliquid-testnet.xyz"

    static let exchangeURL = "https://api.hyperliquid-testnet.xyz/exchange"

    static let wsURL = "wss://api.hyperliquid-testnet.xyz/ws"

    // MARK: - Chain IDs

    static let signatureChainId =  "0x66eee"
    static let userSignedChainId = 421614
    static let chainName = "Testnet"

    // MARK: - EIP-712

    static let phantomAgentSource = "b"
}
