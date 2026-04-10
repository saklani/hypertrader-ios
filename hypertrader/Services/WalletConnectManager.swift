import Foundation
import UIKit

/// High-level wallet connection manager. Uses WalletConnectClient for the protocol,
/// exposes Observable state for SwiftUI views.
@Observable
@MainActor
final class WalletConnectManager {
    static let shared = WalletConnectManager()

    // MARK: - State

    private(set) var isConnected = false
    private(set) var walletAddress: String?
    private(set) var isLoading = false
    private(set) var error: String?

    /// Whether an agent key exists and has been approved for trading.
    /// Canonical observable source of truth — reads `KeychainManager.hasAgentKey`
    /// at init and is updated by `AuthViewModel.setupAgentWallet()` on approval.
    /// Views depending on "is the user fully set up to trade" should read this
    /// via `MarketViewModel.isWalletReady` (or directly) instead of calling
    /// `KeychainManager.hasAgentKey`, which is non-observable.
    var isAgentReady = false

    private var wcClient: WalletConnectClient?

    // MARK: - Initialization

    func initialize() {
        let projectId = "61711db68ae8ac06d236a9a2534dbfee"

        wcClient = WalletConnectClient(
            projectId: projectId,
            metadata: WalletConnectAppMetadata(
                name: "Hypertrader",
                description: "Trade on Hyperliquid",
                url: "https://hypertrader.app",
                icons: ["https://hypertrader.app/icon.png"]
            )
        )

        // Seed agent-ready state from Keychain so the app launches in the right
        // state when the user already has an approved agent from a prior session.
        isAgentReady = KeychainManager.hasAgentKey
    }

    // MARK: - Connect Wallet

    /// Connect to a wallet app. Creates pairing, publishes the session proposal, opens the
    /// wallet deep link, and waits for the wallet to approve.
    func connect(wallet: WalletApp = .rainbow) async throws -> String {
        guard let wcClient else { throw WalletConnectError.notPaired }
        isLoading = true
        error = nil

        do {
            let uri = try await wcClient.createPairingURI()

            // Publish the session proposal BEFORE opening the wallet so there's a
            // message waiting on the pairing topic when the wallet connects.
            try await wcClient.prepareSession()

            if let deepLink = wallet.deepLink(uri: uri) {
                await UIApplication.shared.open(deepLink)
            }

            let address = try await wcClient.awaitSession()

            walletAddress = address
            isConnected = true
            isLoading = false
            return address
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            throw error
        }
    }

    // MARK: - Manual URI / QR Flow (no wallet app installed, or cross-device)

    /// Generate a WC URI and publish the session proposal to the relay so the wallet has
    /// a message waiting the moment it scans the QR (or pastes the URI).
    func generateURI() async throws -> String {
        guard let wcClient else { throw WalletConnectError.notPaired }
        isLoading = true
        error = nil
        do {
            let uri = try await wcClient.createPairingURI()
            try await wcClient.prepareSession()
            return uri
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            throw error
        }
    }

    /// Wait for the wallet to approve the pending session proposal.
    /// Assumes `generateURI()` (or `connect()`) has already called `prepareSession`.
    func waitForSession() async throws -> String {
        guard let wcClient else { throw WalletConnectError.notPaired }

        do {
            let address = try await wcClient.awaitSession()
            walletAddress = address
            isConnected = true
            isLoading = false
            return address
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            throw error
        }
    }

    // MARK: - Sign Typed Data

    /// Request the connected wallet to sign EIP-712 typed data.
    /// Opens the wallet app for approval.
    func signTypedData(_ typedData: EIP712TypedData, wallet: WalletApp = .rainbow) async throws -> String {
        guard let wcClient, let address = walletAddress else {
            throw WalletConnectError.noSession
        }

        guard let jsonString = typedData.toJSONString() else {
            throw HLError.encodingFailed("Failed to serialize typed data")
        }

        // Open wallet for signing prompt
        if let deepLink = URL(string: "\(wallet.rawValue)://") {
            await UIApplication.shared.open(deepLink)
        }

        return try await wcClient.signTypedData(
            address: address,
            typedDataJSON: jsonString
        )
    }

    // MARK: - Disconnect

    func disconnect() async {
        await wcClient?.disconnect()
        walletAddress = nil
        isConnected = false
    }
}
