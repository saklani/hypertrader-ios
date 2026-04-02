import Foundation
import libsecp256k1

/// Local Ethereum signing: keypair generation, EIP-712 hashing, and secp256k1 ECDSA.
enum EthSigner {

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
        let privKeyBytes = Array(privateKey)

        var pubKey = secp256k1_pubkey()
        guard secp256k1_ec_pubkey_create(context, &pubKey, privKeyBytes) == 1 else {
            return "0x0000000000000000000000000000000000000000"
        }

        // Serialize as uncompressed (65 bytes: 0x04 || x || y)
        var pubKeyBytes = [UInt8](repeating: 0, count: 65)
        var pubKeyLen = 65
        secp256k1_ec_pubkey_serialize(context, &pubKeyBytes, &pubKeyLen, &pubKey, UInt32(SECP256K1_EC_UNCOMPRESSED))

        // Ethereum address = last 20 bytes of keccak256(pubkey without 0x04 prefix)
        let keyBytes = Array(pubKeyBytes.dropFirst()) // drop 0x04, 64 bytes remain
        let hash = Keccak.keccak256(keyBytes)
        let addressBytes = Array(hash.suffix(20))
        return "0x" + Data(addressBytes).toHexString()
    }

    // MARK: - EIP-712 Signing

    /// Sign EIP-712 typed data with a local private key.
    /// Returns the signature as a hex string (0x + r + s + v).
    static func signTypedData(
        _ typedData: EIP712TypedData,
        privateKey: Data
    ) throws -> String {
        let digest = try hashTypedData(typedData)
        return try signDigest(digest, privateKey: privateKey)
    }

    /// Compute the EIP-712 hash: keccak256("\x19\x01" || domainSeparator || messageHash)
    static func hashTypedData(_ typedData: EIP712TypedData) throws -> Data {
        let domainSeparator = try hashStruct(
            typeName: "EIP712Domain",
            data: typedData.domain,
            types: typedData.types
        )
        let messageHash = try hashStruct(
            typeName: typedData.primaryType,
            data: typedData.message,
            types: typedData.types
        )

        var input = Data([0x19, 0x01])
        input.append(domainSeparator)
        input.append(messageHash)
        return Keccak.keccak256(input)
    }

    // MARK: - EIP-712 Struct Hashing

    private static func hashStruct(
        typeName: String,
        data: [String: AnyJSON],
        types: [String: [EIP712Field]]
    ) throws -> Data {
        guard let fields = types[typeName] else {
            throw HLError.encodingFailed("Unknown type: \(typeName)")
        }

        let typeString = encodeType(typeName: typeName, types: types)
        let typeHash = Keccak.keccak256(Array(typeString.utf8))

        var encoded = Data(typeHash)
        for field in fields {
            let value = data[field.name] ?? .null
            let encodedValue = try encodeField(type: field.type, value: value, types: types)
            encoded.append(encodedValue)
        }

        return Keccak.keccak256(encoded)
    }

    private static func encodeType(
        typeName: String,
        types: [String: [EIP712Field]]
    ) -> String {
        guard let fields = types[typeName] else { return "" }
        let params = fields.map { "\($0.type) \($0.name)" }.joined(separator: ",")
        return "\(typeName)(\(params))"
    }

    private static func encodeField(
        type: String,
        value: AnyJSON,
        types: [String: [EIP712Field]]
    ) throws -> Data {
        switch type {
        case "string":
            guard let str = value.stringValue else {
                return Data(repeating: 0, count: 32)
            }
            return Data(Keccak.keccak256(Array(str.utf8)))

        case "bytes32":
            guard let hex = value.stringValue else {
                return Data(repeating: 0, count: 32)
            }
            return hexToBytes32(hex)

        case "address":
            guard let hex = value.stringValue else {
                return Data(repeating: 0, count: 32)
            }
            return hexToBytes32(hex)

        case "uint256", "uint64":
            if let intVal = value.intValue {
                return uint256ToBytes32(UInt64(intVal))
            }
            if let u64Val = value.uint64Value {
                return uint256ToBytes32(u64Val)
            }
            return Data(repeating: 0, count: 32)

        case "bool":
            var data = Data(repeating: 0, count: 32)
            if case .bool(let b) = value, b {
                data[31] = 1
            }
            return data

        default:
            if types[type] != nil {
                throw HLError.encodingFailed("Nested struct encoding not implemented: \(type)")
            }
            throw HLError.encodingFailed("Unknown EIP-712 field type: \(type)")
        }
    }

    // MARK: - secp256k1 ECDSA Signing

    private static func signDigest(_ digest: Data, privateKey: Data) throws -> String {
        let digestBytes = Array(digest)
        let privKeyBytes = Array(privateKey)

        guard digestBytes.count == 32, privKeyBytes.count == 32 else {
            throw HLError.signingFailed("Invalid digest or key length")
        }

        var signature = secp256k1_ecdsa_recoverable_signature()
        guard secp256k1_ecdsa_sign_recoverable(
            context, &signature, digestBytes, privKeyBytes, nil, nil
        ) == 1 else {
            throw HLError.signingFailed("secp256k1_ecdsa_sign_recoverable failed")
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

    // MARK: - Byte Helpers

    private static func hexToBytes32(_ hex: String) -> Data {
        var cleanHex = hex
        if cleanHex.hasPrefix("0x") {
            cleanHex = String(cleanHex.dropFirst(2))
        }
        cleanHex = String(repeating: "0", count: max(0, 64 - cleanHex.count)) + cleanHex
        cleanHex = String(cleanHex.suffix(64))

        var data = Data()
        var index = cleanHex.startIndex
        for _ in 0..<32 {
            let nextIndex = cleanHex.index(index, offsetBy: 2)
            let byteStr = cleanHex[index..<nextIndex]
            if let byte = UInt8(byteStr, radix: 16) {
                data.append(byte)
            }
            index = nextIndex
        }
        return data
    }

    private static func uint256ToBytes32(_ value: UInt64) -> Data {
        var data = Data(repeating: 0, count: 24)
        var bigEndian = value.bigEndian
        data.append(Data(bytes: &bigEndian, count: 8))
        return data
    }
}

// MARK: - Data Hex Extension

extension Data {
    func toHexString() -> String {
        map { String(format: "%02x", $0) }.joined()
    }
}
