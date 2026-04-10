import Foundation

/// Central network configuration. Flip `isMainnet` to switch all services.
nonisolated enum HyperliquidConfig {

    // MARK: - URLs

    static let infoURL = "https://api.hyperliquid.xyz"

    static let exchangeURL = "https://api.hyperliquid.xyz/exchange"

    static let wsURL = "wss://api.hyperliquid.xyz/ws"

    // MARK: - Chain IDs

    static let signatureChainId =  "0xa4b1"
    static let userSignedChainId = 42161
    static let chainName = "Mainnet"

    // MARK: - EIP-712

    static let phantomAgentSource = "a"
}
