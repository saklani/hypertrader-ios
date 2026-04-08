import Foundation
import libsecp256k1

enum EthereumSignerError: LocalizedError {
    case invalidLength(String)
    case signingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidLength(let message): return "Invalid length: \(message)"
        case .signingFailed(let message): return "Signing failed: \(message)"
        }
    }
}

/// Low-level Ethereum primitives: key generation, address derivation, secp256k1 ECDSA signing.
/// All functions are nonisolated — safe to call from any thread. Threading is the caller's concern.
nonisolated enum EthereumSigner {

    // MARK: - secp256k1 Context

    private static let context: OpaquePointer = {
        secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY))!
    }()

    // MARK: - Key Generation

    /// Generate a new random secp256k1 private key (32 bytes)
    static func generatePrivateKey() -> Data {
        var keyBytes = [UInt8](repeating: 0, count: 32)
        repeat {
            _ = SecRandomCopyBytes(kSecRandomDefault, 32, &keyBytes)
        } while secp256k1_ec_seckey_verify(context, keyBytes) != 1
        return Data(keyBytes)
    }

    /// Derive Ethereum address from a private key
    static func deriveAddress(from privateKey: Data) -> String {
        let privateKeyBytes = Array(privateKey)

        var publicKey = secp256k1_pubkey()
        guard secp256k1_ec_pubkey_create(context, &publicKey, privateKeyBytes) == 1 else {
            return "0x0000000000000000000000000000000000000000"
        }

        var publicKeyBytes = [UInt8](repeating: 0, count: 65)
        var publicKeyLen = 65
        secp256k1_ec_pubkey_serialize(context, &publicKeyBytes, &publicKeyLen, &publicKey, UInt32(SECP256K1_EC_UNCOMPRESSED))

        let keyBytes = Array(publicKeyBytes.dropFirst())
        let hash = Keccak.keccak256(keyBytes)
        let addressBytes = Array(hash.suffix(20))
        return "0x" + Data(addressBytes).toHexString()
    }

    // MARK: - ECDSA Signing

    /// Sign a 32-byte digest with a private key. Returns "0x" + r(64) + s(64) + v(2) hex string.
    static func sign(privateKey: Data, digest: Data) throws -> String {
        let digestBytes = Array(digest)
        let privateKeyBytes = Array(privateKey)

        guard digestBytes.count == 32, privateKeyBytes.count == 32 else {
            throw EthereumSignerError.invalidLength("Digest and key must be 32 bytes")
        }

        var signature = secp256k1_ecdsa_recoverable_signature()
        guard secp256k1_ecdsa_sign_recoverable(
            context, &signature, digestBytes, privateKeyBytes, nil, nil
        ) == 1 else {
            throw EthereumSignerError.signingFailed("secp256k1_ecdsa_sign_recoverable failed")
        }

        var compactSig = [UInt8](repeating: 0, count: 64)
        var recId: Int32 = 0
        secp256k1_ecdsa_recoverable_signature_serialize_compact(
            context, &compactSig, &recId, &signature
        )

        let v = Int(recId) + 27
        let r = Data(compactSig[0..<32])
        let s = Data(compactSig[32..<64])

        return "0x" + r.toHexString() + s.toHexString() + String(format: "%02x", v)
    }
}

// MARK: - Data Hex Extension

extension Data {
    nonisolated func toHexString() -> String {
        map { String(format: "%02x", $0) }.joined()
    }
}
