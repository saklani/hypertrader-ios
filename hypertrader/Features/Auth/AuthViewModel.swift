import Foundation

/// Drives the wallet connection flow: picking a wallet, connecting via
/// WalletConnect, and the manual QR/URI fallback. Agent approval is handled
/// separately by `AgentViewModel`.
@Observable
@MainActor
final class AuthViewModel {
    let wcManager = WalletConnectManager.shared

    var selectedWallet: WalletApp = .rainbow
    private(set) var setupError: String?
    private(set) var pendingURI: String?

    // MARK: - Connect Wallet

    func connectWallet() async {
        do {
            _ = try await wcManager.connect(wallet: selectedWallet)
        } catch {
            setupError = error.localizedDescription
        }
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
    }

    var shortAddress: String {
        guard let addr = wcManager.walletAddress else { return "Not connected" }
        return formatShortAddress(addr)
    }
}
