import Foundation
import UIKit
import CryptoKit

// MARK: - Minimal WalletConnect v2 Protocol Client

/// A lightweight WalletConnect v2 dApp client using only CryptoKit and URLSession.
/// Supports: pairing, session proposal, eth_signTypedData_v4 requests.
actor WCClient {

    // MARK: - Configuration

    private let projectId: String
    private let metadata: WCAppMetadata

    // MARK: - Relay

    private var webSocket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private let urlSession = URLSession(configuration: .default)

    // MARK: - Pairing

    private var pairingSymKey: SymmetricKey?
    private var pairingTopic: String?

    // MARK: - Session Proposal

    private var proposerKeyPair: Curve25519.KeyAgreement.PrivateKey?

    // MARK: - Session

    private var sessionSymKey: SymmetricKey?
    private(set) var sessionTopic: String?
    private(set) var connectedAddress: String?
    private(set) var isSessionEstablished = false

    // MARK: - Relay Auth

    private let relayKeyPair: Curve25519.Signing.PrivateKey

    // MARK: - Async Continuations

    private var sessionContinuation: CheckedContinuation<String, Error>?
    private var requestContinuations: [Int64: CheckedContinuation<String, Error>] = [:]
    private var relayContinuations: [Int64: CheckedContinuation<Any, Error>] = [:]

    // MARK: - Init

    init(projectId: String, metadata: WCAppMetadata) {
        self.projectId = projectId
        self.metadata = metadata

        // Load or generate Ed25519 key for relay auth (not sensitive — just a client identity)
        let keyTag = "com.hypertrader.wc.relay.ed25519"
        if let saved = UserDefaults.standard.data(forKey: keyTag),
           let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: saved) {
            self.relayKeyPair = key
        } else {
            let key = Curve25519.Signing.PrivateKey()
            UserDefaults.standard.set(key.rawRepresentation, forKey: keyTag)
            self.relayKeyPair = key
        }
    }

    // MARK: - Connect (full flow: pairing → session)

    /// Create a pairing, connect to relay, propose session, wait for approval.
    /// Returns the wallet URI for deep-linking. Call `waitForSession()` after opening the deep link.
    func createPairingURI() throws -> String {
        // Generate pairing symmetric key and topic
        let symKeyBytes = SymmetricKey(size: .bits256)
        let symKeyHex = Self.hexEncode(symKeyBytes)
        let topic = Self.topicFromKey(symKeyBytes)

        pairingSymKey = symKeyBytes
        pairingTopic = topic

        // Generate X25519 key pair for session proposal
        proposerKeyPair = Curve25519.KeyAgreement.PrivateKey()

        // Build URI
        let expiry = Int(Date().timeIntervalSince1970) + 300
        let uri = "wc:\(topic)@2?symKey=\(symKeyHex)&relay-protocol=irn&methods=[wc_sessionPropose]&expiryTimestamp=\(expiry)"
        return uri
    }

    /// Connect to the relay, subscribe, propose session, and wait for the wallet to approve.
    /// Returns the connected wallet address.
    func connectAndWaitForSession() async throws -> String {
        guard let pairingTopic, let pairingSymKey, let proposerKeyPair else {
            throw WCError.notPaired
        }

        // Connect WebSocket to relay
        try await connectRelay()

        // Subscribe to pairing topic
        try await subscribe(topic: pairingTopic)

        // Send session proposal
        let proposalId = Self.generateId()
        let proposal = Self.buildSessionProposal(
            id: proposalId,
            publicKey: Self.hexEncode(proposerKeyPair.publicKey.rawRepresentation),
            metadata: metadata
        )
        let proposalJSON = try JSONSerialization.data(withJSONObject: proposal)
        let encrypted = try Self.encrypt(data: proposalJSON, key: pairingSymKey)
        try await publish(topic: pairingTopic, message: encrypted, tag: 1100, ttl: 300)

        // Wait for session to be established (approval + settle)
        let address = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            self.sessionContinuation = continuation
        }

        return address
    }

    // MARK: - Session Request

    /// Send an eth_signTypedData_v4 request to the connected wallet.
    /// Returns the signature hex string.
    func signTypedData(address: String, typedDataJSON: String, chainId: String = "eip155:1") async throws -> String {
        guard let sessionTopic, let sessionSymKey else {
            throw WCError.noSession
        }

        let requestId = Self.generateId()
        let request: [String: Any] = [
            "id": requestId,
            "jsonrpc": "2.0",
            "method": "wc_sessionRequest",
            "params": [
                "request": [
                    "method": "eth_signTypedData_v4",
                    "params": [address, typedDataJSON]
                ],
                "chainId": chainId
            ] as [String: Any]
        ]

        let requestJSON = try JSONSerialization.data(withJSONObject: request)
        let encrypted = try Self.encrypt(data: requestJSON, key: sessionSymKey)
        try await publish(topic: sessionTopic, message: encrypted, tag: 1108, ttl: 300)

        // Wait for response
        return try await withCheckedThrowingContinuation { continuation in
            self.requestContinuations[requestId] = continuation
        }
    }

    // MARK: - Disconnect

    func disconnect() async {
        receiveTask?.cancel()
        receiveTask = nil
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        sessionSymKey = nil
        sessionTopic = nil
        connectedAddress = nil
        isSessionEstablished = false
        pairingSymKey = nil
        pairingTopic = nil

        // Fail any pending continuations
        sessionContinuation?.resume(throwing: WCError.disconnected)
        sessionContinuation = nil
        for (_, cont) in requestContinuations {
            cont.resume(throwing: WCError.disconnected)
        }
        requestContinuations.removeAll()
    }

    // MARK: - Relay Connection

    private func connectRelay() async throws {
        let jwt = try Self.generateRelayJWT(keyPair: relayKeyPair)
        let urlString = "wss://relay.walletconnect.com?auth=\(jwt)&projectId=\(projectId)&ua=wc-2/swift-1.0/ios"
        guard let url = URL(string: urlString) else {
            throw WCError.invalidURL
        }

        let ws = urlSession.webSocketTask(with: url)
        ws.resume()
        webSocket = ws
        startReceiveLoop()
    }

    private func startReceiveLoop() {
        receiveTask = Task {
            while !Task.isCancelled {
                guard let ws = webSocket else { break }
                do {
                    let message = try await ws.receive()
                    switch message {
                    case .string(let text):
                        handleWebSocketMessage(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            handleWebSocketMessage(text)
                        }
                    @unknown default:
                        break
                    }
                } catch {
                    break
                }
            }
        }
    }

    // MARK: - Relay Methods

    private func subscribe(topic: String) async throws {
        let id = Self.generateId()
        let msg: [String: Any] = [
            "id": id,
            "jsonrpc": "2.0",
            "method": "irn_subscribe",
            "params": ["topic": topic]
        ]
        try await sendJSON(msg)
    }

    private func publish(topic: String, message: String, tag: Int, ttl: Int) async throws {
        let id = Self.generateId()
        let msg: [String: Any] = [
            "id": id,
            "jsonrpc": "2.0",
            "method": "irn_publish",
            "params": [
                "topic": topic,
                "message": message,
                "ttl": ttl,
                "tag": tag
            ] as [String: Any]
        ]
        try await sendJSON(msg)
    }

    private func sendJSON(_ object: [String: Any]) async throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        guard let text = String(data: data, encoding: .utf8) else {
            throw WCError.encodingFailed
        }
        try await webSocket?.send(.string(text))
    }

    // MARK: - Message Handling

    private func handleWebSocketMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        let id = json["id"] as? Int64 ?? (json["id"] as? Int).map(Int64.init) ?? 0

        // Check if it's an irn_subscription delivery (from relay)
        if let method = json["method"] as? String, method == "irn_subscription" {
            // Acknowledge the delivery
            Task {
                let ack: [String: Any] = ["id": id, "jsonrpc": "2.0", "result": true]
                try? await sendJSON(ack)
            }

            // Process the encrypted payload
            if let params = json["params"] as? [String: Any],
               let subData = params["data"] as? [String: Any],
               let topic = subData["topic"] as? String,
               let envelope = subData["message"] as? String {
                handleEncryptedMessage(envelope: envelope, topic: topic)
            }
        }
    }

    private func handleEncryptedMessage(envelope: String, topic: String) {
        // Determine which key to use based on topic
        let key: SymmetricKey?
        if topic == pairingTopic {
            key = pairingSymKey
        } else if topic == sessionTopic {
            key = sessionSymKey
        } else {
            return
        }

        guard let key,
              let decrypted = try? Self.decrypt(envelope: envelope, key: key),
              let json = try? JSONSerialization.jsonObject(with: decrypted) as? [String: Any] else { return }

        let id = json["id"] as? Int64 ?? (json["id"] as? Int).map(Int64.init) ?? 0

        if let method = json["method"] as? String {
            // Incoming request from wallet
            handleIncomingRequest(method: method, id: id, json: json, topic: topic)
        } else if json["result"] != nil || json["error"] != nil {
            // Response to our request
            handleResponse(id: id, json: json)
        }
    }

    private func handleIncomingRequest(method: String, id: Int64, json: [String: Any], topic: String) {
        switch method {
        case "wc_sessionSettle":
            // Extract wallet address from the settle message
            if let params = json["params"] as? [String: Any],
               let namespaces = params["namespaces"] as? [String: Any],
               let eip155 = namespaces["eip155"] as? [String: Any],
               let accounts = eip155["accounts"] as? [String] {

                // Account format: "eip155:1:0xAddress"
                if let firstAccount = accounts.first {
                    let parts = firstAccount.split(separator: ":")
                    if parts.count >= 3 {
                        connectedAddress = String(parts[2])
                    }
                }
                isSessionEstablished = true

                // Send ack
                Task {
                    guard let sessionSymKey, let sessionTopic else { return }
                    let ack: [String: Any] = ["id": id, "jsonrpc": "2.0", "result": true]
                    let ackData = try JSONSerialization.data(withJSONObject: ack)
                    let encrypted = try Self.encrypt(data: ackData, key: sessionSymKey)
                    try await publish(topic: sessionTopic, message: encrypted, tag: 1103, ttl: 300)
                }

                // Resume session continuation
                if let address = connectedAddress {
                    sessionContinuation?.resume(returning: address)
                    sessionContinuation = nil
                }
            }

        default:
            break
        }
    }

    private func handleResponse(id: Int64, json: [String: Any]) {
        // Check for session proposal approval
        if let result = json["result"] as? [String: Any],
           let responderPubKeyHex = result["responderPublicKey"] as? String {
            handleSessionApproval(responderPublicKeyHex: responderPubKeyHex)
            return
        }

        // Check for session request response (signature)
        if let continuation = requestContinuations.removeValue(forKey: id) {
            if let result = json["result"] as? String {
                continuation.resume(returning: result)
            } else if let error = json["error"] as? [String: Any],
                      let message = error["message"] as? String {
                continuation.resume(throwing: WCError.walletRejected(message))
            } else {
                continuation.resume(throwing: WCError.unexpectedResponse)
            }
        }
    }

    private func handleSessionApproval(responderPublicKeyHex: String) {
        guard let proposerKeyPair else { return }

        do {
            // Derive session symmetric key
            let responderPubKeyBytes = Self.hexDecode(responderPublicKeyHex)
            let responderPubKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: responderPubKeyBytes)
            let derived = try Self.deriveSymKey(privateKey: proposerKeyPair, publicKey: responderPubKey)

            sessionSymKey = derived
            let sTopic = Self.topicFromKey(derived)
            sessionTopic = sTopic

            // Subscribe to session topic
            Task {
                try await subscribe(topic: sTopic)
            }
        } catch {
            sessionContinuation?.resume(throwing: error)
            sessionContinuation = nil
        }
    }

    // MARK: - Crypto: Envelope Encryption (ChaCha20-Poly1305)

    /// Encrypt data into a Type 0 envelope: base64(0x00 || nonce[12] || sealed)
    static func encrypt(data: Data, key: SymmetricKey) throws -> String {
        let nonce = ChaChaPoly.Nonce()
        let sealed = try ChaChaPoly.seal(data, using: key, nonce: nonce)

        var envelope = Data([0x00])
        envelope.append(contentsOf: nonce)
        envelope.append(sealed.ciphertext)
        envelope.append(sealed.tag)

        return envelope.base64EncodedString()
    }

    /// Decrypt a Type 0 envelope: base64 → 0x00 || nonce[12] || sealed
    static func decrypt(envelope: String, key: SymmetricKey) throws -> Data {
        guard let bytes = Data(base64Encoded: envelope), bytes.count > 13 else {
            throw WCError.decryptionFailed
        }

        let type = bytes[0]
        guard type == 0x00 else { throw WCError.decryptionFailed }

        let nonce = try ChaChaPoly.Nonce(data: bytes[1..<13])
        let ciphertextAndTag = bytes[13...]

        guard ciphertextAndTag.count >= 16 else { throw WCError.decryptionFailed }
        let tagStart = ciphertextAndTag.endIndex - 16
        let ciphertext = ciphertextAndTag[ciphertextAndTag.startIndex..<tagStart]
        let tag = ciphertextAndTag[tagStart...]

        let sealedBox = try ChaChaPoly.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        return try ChaChaPoly.open(sealedBox, using: key)
    }

    // MARK: - Crypto: Key Derivation

    /// Derive a symmetric key from X25519 key agreement + HKDF-SHA256
    static func deriveSymKey(
        privateKey: Curve25519.KeyAgreement.PrivateKey,
        publicKey: Curve25519.KeyAgreement.PublicKey
    ) throws -> SymmetricKey {
        let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: publicKey)
        return sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data(),
            outputByteCount: 32
        )
    }

    /// Compute topic from symmetric key: SHA256(keyBytes) as hex
    static func topicFromKey(_ key: SymmetricKey) -> String {
        key.withUnsafeBytes { bytes in
            let hash = SHA256.hash(data: bytes)
            return hash.map { String(format: "%02x", $0) }.joined()
        }
    }

    // MARK: - Crypto: Relay JWT (Ed25519)

    static func generateRelayJWT(keyPair: Curve25519.Signing.PrivateKey) throws -> String {
        let header = ["alg": "EdDSA", "typ": "JWT"]
        let now = Int(Date().timeIntervalSince1970)
        let sub = UUID().uuidString

        // Build did:key from Ed25519 public key
        let pubKeyBytes = keyPair.publicKey.rawRepresentation
        var multicodec = Data([0xed, 0x01])
        multicodec.append(pubKeyBytes)
        let didKey = "did:key:z" + base58Encode(Array(multicodec))

        let payload: [String: Any] = [
            "iss": didKey,
            "sub": sub,
            "aud": "wss://relay.walletconnect.com",
            "iat": now,
            "exp": now + 86400,
            "act": "client_auth"
        ]

        let headerB64 = try base64url(JSONSerialization.data(withJSONObject: header))
        let payloadB64 = try base64url(JSONSerialization.data(withJSONObject: payload))
        let signingInput = "\(headerB64).\(payloadB64)"
        let signature = try keyPair.signature(for: Data(signingInput.utf8))
        let sigB64 = base64url(signature)

        return "\(signingInput).\(sigB64)"
    }

    // MARK: - Session Proposal Builder

    static func buildSessionProposal(id: Int64, publicKey: String, metadata: WCAppMetadata) -> [String: Any] {
        [
            "id": id,
            "jsonrpc": "2.0",
            "method": "wc_sessionPropose",
            "params": [
                "relays": [["protocol": "irn"]],
                "proposer": [
                    "publicKey": publicKey,
                    "metadata": [
                        "name": metadata.name,
                        "description": metadata.description,
                        "url": metadata.url,
                        "icons": metadata.icons
                    ]
                ],
                "requiredNamespaces": [
                    "eip155": [
                        "chains": ["eip155:1"],
                        "methods": ["personal_sign", "eth_signTypedData_v4"],
                        "events": ["chainChanged", "accountsChanged"]
                    ]
                ]
            ] as [String: Any]
        ]
    }

    // MARK: - ID Generation

    /// 13-digit epoch millis + 6-digit random
    static func generateId() -> Int64 {
        let ms = Int64(Date().timeIntervalSince1970 * 1000)
        let rand = Int64.random(in: 100000...999999)
        return ms * 1000000 + rand
    }

    // MARK: - Base64url

    static func base64url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Base58 (for did:key encoding)

    static func base58Encode(_ bytes: [UInt8]) -> String {
        let alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
        let leadingZeros = bytes.prefix(while: { $0 == 0 }).count
        var num = bytes
        var result = [Character]()

        while num.contains(where: { $0 != 0 }) {
            var remainder: UInt32 = 0
            var newNum = [UInt8]()
            for byte in num {
                let value = remainder * 256 + UInt32(byte)
                let digit = value / 58
                remainder = value % 58
                if !newNum.isEmpty || digit > 0 {
                    newNum.append(UInt8(digit))
                }
            }
            result.append(alphabet[Int(remainder)])
            num = newNum.isEmpty ? [0] : newNum
        }

        for _ in 0..<leadingZeros {
            result.append(alphabet[0])
        }

        return String(result.reversed())
    }

    // MARK: - Hex Helpers

    private static func hexEncode(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    private static func hexEncode(_ key: SymmetricKey) -> String {
        key.withUnsafeBytes { bytes in
            bytes.map { String(format: "%02x", $0) }.joined()
        }
    }

    private static func hexDecode(_ hex: String) -> Data {
        var hex = hex
        if hex.hasPrefix("0x") { hex = String(hex.dropFirst(2)) }
        var data = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
            if let byte = UInt8(hex[index..<nextIndex], radix: 16) {
                data.append(byte)
            }
            index = nextIndex
        }
        return data
    }
}

// MARK: - Supporting Types

struct WCAppMetadata {
    let name: String
    let description: String
    let url: String
    let icons: [String]
}

enum WCError: LocalizedError {
    case notPaired
    case noSession
    case invalidURL
    case encodingFailed
    case decryptionFailed
    case disconnected
    case walletRejected(String)
    case unexpectedResponse
    case timeout

    var errorDescription: String? {
        switch self {
        case .notPaired: return "Not paired with wallet"
        case .noSession: return "No active session"
        case .invalidURL: return "Invalid relay URL"
        case .encodingFailed: return "Message encoding failed"
        case .decryptionFailed: return "Message decryption failed"
        case .disconnected: return "Disconnected from wallet"
        case .walletRejected(let msg): return "Wallet rejected: \(msg)"
        case .unexpectedResponse: return "Unexpected response from wallet"
        case .timeout: return "Request timed out"
        }
    }
}

/// Wallet apps and their deep link schemes
enum WalletApp: String, CaseIterable, Identifiable {
    case rainbow
    case metamask
    case coinbase

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rainbow: return "Rainbow"
        case .metamask: return "MetaMask"
        case .coinbase: return "Coinbase Wallet"
        }
    }

    var scheme: String {
        switch self {
        case .rainbow: return "rainbow://"
        case .metamask: return "metamask://"
        case .coinbase: return "cbwallet://"
        }
    }

    func deepLink(uri: String) -> URL? {
        let encoded = uri.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? uri
        switch self {
        case .rainbow: return URL(string: "rainbow://wc?uri=\(encoded)")
        case .metamask: return URL(string: "metamask://wc?uri=\(encoded)")
        case .coinbase: return URL(string: "cbwallet://wc?uri=\(encoded)")
        }
    }

    var iconName: String {
        switch self {
        case .rainbow: return "rainbow"
        case .metamask: return "fox.fill"
        case .coinbase: return "c.circle.fill"
        }
    }

    /// Check if this wallet app is installed on the device
    @MainActor
    var isInstalled: Bool {
        guard let url = URL(string: scheme) else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    /// Wallets that are currently installed, plus a note if none are
    @MainActor
    static var installed: [WalletApp] {
        allCases.filter { $0.isInstalled }
    }
}

