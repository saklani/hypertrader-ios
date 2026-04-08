import Foundation

/// Drives the wallet connection → agent setup → approval flow.
@Observable
@MainActor
final class AuthViewModel {
    let wcManager = WalletConnectManager.shared

    var selectedWallet: WalletApp = .rainbow
    private(set) var agentAddress: String?
    private(set) var isAgentApproved = false
    private(set) var isSettingUpAgent = false
    private(set) var setupError: String?
    private(set) var pendingURI: String?

    var isFullyReady: Bool {
        wcManager.isConnected && isAgentApproved
    }

    // MARK: - Step 1: Connect Wallet

    func connectWallet() async {
        do {
            _ = try await wcManager.connect(wallet: selectedWallet)
        } catch {
            setupError = error.localizedDescription
        }
    }

    // MARK: - Step 2: Setup Agent Wallet + Approve

    func setupAgentWallet() async {
        isSettingUpAgent = true
        setupError = nil

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
            let signatureHex = try await wcManager.signTypedData(typedData, wallet: selectedWallet)

            guard let signature = HyperliquidSigner.parse(signature: signatureHex) else {
                throw HLError.signingFailed("Invalid signature from wallet")
            }

            // Post approveAgent to Hyperliquid
            try await HyperliquidExchangeService.shared.approveAgent(
                agentAddress: agentAddr,
                nonce: nonce,
                signature: signature
            )

            isAgentApproved = true
        } catch {
            setupError = error.localizedDescription
        }

        isSettingUpAgent = false
    }

    // MARK: - Copy URI Flow (no wallet app installed)

    /// Generate a WC URI without opening a wallet app.
    /// User copies it and pastes into their wallet manually.
    func generateURI() async {
        setupError = nil
        do {
            let uri = try await wcManager.generateURI()
            pendingURI = uri
        } catch {
            setupError = error.localizedDescription
        }
    }

    /// Wait for the wallet to connect after the user pastes the URI.
    func waitForSession() async {
        do {
            _ = try await wcManager.waitForSession()
        } catch {
            setupError = error.localizedDescription
        }
    }

    // MARK: - Disconnect

    func disconnect() async {
        await wcManager.disconnect()
        isAgentApproved = false
        agentAddress = nil
    }

    var shortAddress: String {
        guard let addr = wcManager.walletAddress, addr.count > 10 else {
            return "Not connected"
        }
        return "\(addr.prefix(6))...\(addr.suffix(4))"
    }
}
