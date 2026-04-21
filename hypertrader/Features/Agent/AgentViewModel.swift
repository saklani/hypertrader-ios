import Foundation

/// Drives the agent key generation and on-chain approval flow.
/// Generates (or loads) a local secp256k1 keypair, builds an `approveAgent`
/// EIP-712 message, sends it to the connected wallet for signing, and POSTs
/// the approval to Hyperliquid.
@Observable
@MainActor
final class AgentViewModel {
    private let wcManager = WalletConnectManager.shared

    private(set) var agentAddress: String?
    private(set) var isApproved = false
    private(set) var isLoading = false
    private(set) var error: String?

    /// Run the full agent approval flow: generate/load key → EIP-712 → sign → POST.
    func approve() async {
        isLoading = true
        error = nil

        do {
            // Generate or load agent key
            let agentKey: Data
            if let existing = KeychainManager.loadAgentKey() {
                agentKey = existing
            } else {
                agentKey = EthereumSigner.generatePrivateKey()
                try KeychainManager.saveAgentKey(agentKey)
            }

            let agentAddr = EthereumSigner.deriveAddress(from: agentKey)
            agentAddress = agentAddr

            // Build approveAgent typed data
            let nonce = HyperliquidSigner.generateNonce()
            let typedData = EIP712Builder.approveAgent(
                agentAddress: agentAddr,
                nonce: nonce
            )

            // Send to wallet for signing via WalletConnect
            let signatureHex = try await wcManager.signTypedData(typedData)

            guard let signature = HyperliquidSigner.parse(signature: signatureHex) else {
                throw HLError.signingFailed("Invalid signature from wallet")
            }

            // Post approveAgent to Hyperliquid
            try await HyperliquidExchangeService.shared.approveAgent(
                agentAddress: agentAddr,
                nonce: nonce,
                signature: signature
            )

            isApproved = true
            wcManager.isAgentReady = true
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}
