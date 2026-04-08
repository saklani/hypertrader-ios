import Foundation
import UIKit

/// High-level wallet connection manager. Uses WCClient for the protocol,
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

    private var wcClient: WCClient?

    // MARK: - Initialization

    func initialize() {
        let projectId = "61711db68ae8ac06d236a9a2534dbfee"

        wcClient = WCClient(
            projectId: projectId,
            metadata: WCAppMetadata(
                name: "Hypertrader",
                description: "Trade on Hyperliquid",
                url: "https://hypertrader.app",
                icons: ["https://hypertrader.app/icon.png"]
            )
        )
    }

    // MARK: - Connect Wallet

    /// Connect to a wallet app. Creates pairing, opens the wallet, waits for session.
    func connect(wallet: WalletApp = .rainbow) async throws -> String {
        guard let wcClient else { throw WCError.notPaired }
        isLoading = true
        error = nil

        do {
            // Create pairing URI
            let uri = try await wcClient.createPairingURI()

            // Deep link to wallet app
            if let deepLink = wallet.deepLink(uri: uri) {
                await UIApplication.shared.open(deepLink)
            }

            // Wait for session establishment
            let address = try await wcClient.connectAndWaitForSession()

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

    // MARK: - Manual URI Flow (no wallet app installed)

    /// Generate a WC URI without opening any wallet app.
    /// The user copies it and pastes into their wallet manually.
    func generateURI() async throws -> String {
        guard let wcClient else { throw WCError.notPaired }
        isLoading = true
        error = nil
        let uri = try await wcClient.createPairingURI()
        return uri
    }

    /// Wait for the wallet to connect after the user pastes the URI.
    func waitForSession() async throws -> String {
        guard let wcClient else { throw WCError.notPaired }

        do {
            let address = try await wcClient.connectAndWaitForSession()
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
            throw WCError.noSession
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
