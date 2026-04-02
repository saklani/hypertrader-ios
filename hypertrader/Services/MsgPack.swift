import Foundation

/// Minimal MessagePack encoder for Codable structs.
/// Supports: String, Int, Bool, nil, nested maps, arrays.
final class MsgPackEncoder {

    /// Encode a Codable value to MessagePack bytes
    func encode<T: Encodable>(_ value: T) throws -> Data {
        let impl = MsgPackEncoderImpl()
        try value.encode(to: impl)
        guard let result = impl.data else {
            throw MsgPackError.encodingFailed
        }
        return result
    }
}

enum MsgPackError: Error {
    case encodingFailed
}

// MARK: - Encoder Implementation

private class MsgPackEncoderImpl: Encoder {
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any] = [:]
    var data: Data?

    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        let container = MsgPackKeyedContainer<Key>(encoder: self, codingPath: codingPath)
        return KeyedEncodingContainer(container)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        MsgPackUnkeyedContainer(encoder: self, codingPath: codingPath)
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        MsgPackSingleValueContainer(encoder: self, codingPath: codingPath)
    }
}

// MARK: - Keyed Container (maps/structs)

private class MsgPackKeyedContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    var codingPath: [CodingKey]
    let encoder: MsgPackEncoderImpl
    var entries: [(String, Data)] = []

    init(encoder: MsgPackEncoderImpl, codingPath: [CodingKey]) {
        self.encoder = encoder
        self.codingPath = codingPath
    }

    func encodeNil(forKey key: Key) throws {
        entries.append((key.stringValue, Data([0xc0])))
    }

    func encode(_ value: Bool, forKey key: Key) throws {
        entries.append((key.stringValue, Data([value ? 0xc3 : 0xc2])))
    }

    func encode(_ value: String, forKey key: Key) throws {
        entries.append((key.stringValue, MsgPack.encodeString(value)))
    }

    func encode(_ value: Int, forKey key: Key) throws {
        entries.append((key.stringValue, MsgPack.encodeInt(Int64(value))))
    }

    func encode(_ value: Int8, forKey key: Key) throws { try encode(Int(value), forKey: key) }
    func encode(_ value: Int16, forKey key: Key) throws { try encode(Int(value), forKey: key) }
    func encode(_ value: Int32, forKey key: Key) throws { try encode(Int(value), forKey: key) }
    func encode(_ value: Int64, forKey key: Key) throws {
        entries.append((key.stringValue, MsgPack.encodeInt(value)))
    }

    func encode(_ value: UInt, forKey key: Key) throws {
        entries.append((key.stringValue, MsgPack.encodeUInt(UInt64(value))))
    }
    func encode(_ value: UInt8, forKey key: Key) throws { try encode(UInt(value), forKey: key) }
    func encode(_ value: UInt16, forKey key: Key) throws { try encode(UInt(value), forKey: key) }
    func encode(_ value: UInt32, forKey key: Key) throws { try encode(UInt(value), forKey: key) }
    func encode(_ value: UInt64, forKey key: Key) throws {
        entries.append((key.stringValue, MsgPack.encodeUInt(value)))
    }

    func encode(_ value: Float, forKey key: Key) throws { try encode(Double(value), forKey: key) }
    func encode(_ value: Double, forKey key: Key) throws {
        entries.append((key.stringValue, MsgPack.encodeDouble(value)))
    }

    func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        let sub = MsgPackEncoderImpl()
        sub.codingPath = codingPath + [key]
        try value.encode(to: sub)
        if let data = sub.data {
            entries.append((key.stringValue, data))
        }
    }

    // Override all encodeIfPresent variants so nil optionals encode as msgpack nil, not skipped.
    // Swift has separate default implementations per type that just skip nil.
    func encodeIfPresent(_ value: Bool?, forKey key: Key) throws {
        guard let value else { return try encodeNil(forKey: key) }
        try encode(value, forKey: key)
    }
    func encodeIfPresent(_ value: String?, forKey key: Key) throws {
        guard let value else { return try encodeNil(forKey: key) }
        try encode(value, forKey: key)
    }
    func encodeIfPresent(_ value: Int?, forKey key: Key) throws {
        guard let value else { return try encodeNil(forKey: key) }
        try encode(value, forKey: key)
    }
    func encodeIfPresent(_ value: Int8?, forKey key: Key) throws {
        guard let value else { return try encodeNil(forKey: key) }
        try encode(value, forKey: key)
    }
    func encodeIfPresent(_ value: Int16?, forKey key: Key) throws {
        guard let value else { return try encodeNil(forKey: key) }
        try encode(value, forKey: key)
    }
    func encodeIfPresent(_ value: Int32?, forKey key: Key) throws {
        guard let value else { return try encodeNil(forKey: key) }
        try encode(value, forKey: key)
    }
    func encodeIfPresent(_ value: Int64?, forKey key: Key) throws {
        guard let value else { return try encodeNil(forKey: key) }
        try encode(value, forKey: key)
    }
    func encodeIfPresent(_ value: UInt?, forKey key: Key) throws {
        guard let value else { return try encodeNil(forKey: key) }
        try encode(value, forKey: key)
    }
    func encodeIfPresent(_ value: UInt8?, forKey key: Key) throws {
        guard let value else { return try encodeNil(forKey: key) }
        try encode(value, forKey: key)
    }
    func encodeIfPresent(_ value: UInt16?, forKey key: Key) throws {
        guard let value else { return try encodeNil(forKey: key) }
        try encode(value, forKey: key)
    }
    func encodeIfPresent(_ value: UInt32?, forKey key: Key) throws {
        guard let value else { return try encodeNil(forKey: key) }
        try encode(value, forKey: key)
    }
    func encodeIfPresent(_ value: UInt64?, forKey key: Key) throws {
        guard let value else { return try encodeNil(forKey: key) }
        try encode(value, forKey: key)
    }
    func encodeIfPresent(_ value: Float?, forKey key: Key) throws {
        guard let value else { return try encodeNil(forKey: key) }
        try encode(value, forKey: key)
    }
    func encodeIfPresent(_ value: Double?, forKey key: Key) throws {
        guard let value else { return try encodeNil(forKey: key) }
        try encode(value, forKey: key)
    }
    func encodeIfPresent<T: Encodable>(_ value: T?, forKey key: Key) throws {
        guard let value else { return try encodeNil(forKey: key) }
        try encode(value, forKey: key)
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        let container = MsgPackKeyedContainer<NestedKey>(encoder: encoder, codingPath: codingPath + [key])
        return KeyedEncodingContainer(container)
    }

    func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        MsgPackUnkeyedContainer(encoder: encoder, codingPath: codingPath + [key])
    }

    func superEncoder() -> Encoder { encoder }
    func superEncoder(forKey key: Key) -> Encoder { encoder }

    deinit {
        // Finalize: write map header + entries
        var result = MsgPack.encodeMapHeader(entries.count)
        for (key, value) in entries {
            result.append(MsgPack.encodeString(key))
            result.append(value)
        }
        encoder.data = result
    }
}

// MARK: - Unkeyed Container (arrays)

private class MsgPackUnkeyedContainer: UnkeyedEncodingContainer {
    var codingPath: [CodingKey]
    var count = 0
    let encoder: MsgPackEncoderImpl
    var items: [Data] = []

    init(encoder: MsgPackEncoderImpl, codingPath: [CodingKey]) {
        self.encoder = encoder
        self.codingPath = codingPath
    }

    func encodeNil() throws { items.append(Data([0xc0])); count += 1 }
    func encode(_ value: Bool) throws { items.append(Data([value ? 0xc3 : 0xc2])); count += 1 }
    func encode(_ value: String) throws { items.append(MsgPack.encodeString(value)); count += 1 }
    func encode(_ value: Int) throws { items.append(MsgPack.encodeInt(Int64(value))); count += 1 }
    func encode(_ value: Int8) throws { try encode(Int(value)) }
    func encode(_ value: Int16) throws { try encode(Int(value)) }
    func encode(_ value: Int32) throws { try encode(Int(value)) }
    func encode(_ value: Int64) throws { items.append(MsgPack.encodeInt(value)); count += 1 }
    func encode(_ value: UInt) throws { items.append(MsgPack.encodeUInt(UInt64(value))); count += 1 }
    func encode(_ value: UInt8) throws { try encode(UInt(value)) }
    func encode(_ value: UInt16) throws { try encode(UInt(value)) }
    func encode(_ value: UInt32) throws { try encode(UInt(value)) }
    func encode(_ value: UInt64) throws { items.append(MsgPack.encodeUInt(value)); count += 1 }
    func encode(_ value: Float) throws { try encode(Double(value)) }
    func encode(_ value: Double) throws { items.append(MsgPack.encodeDouble(value)); count += 1 }

    func encode<T: Encodable>(_ value: T) throws {
        let sub = MsgPackEncoderImpl()
        try value.encode(to: sub)
        if let data = sub.data { items.append(data) }
        count += 1
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        KeyedEncodingContainer(MsgPackKeyedContainer<NestedKey>(encoder: encoder, codingPath: codingPath))
    }

    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        MsgPackUnkeyedContainer(encoder: encoder, codingPath: codingPath)
    }

    func superEncoder() -> Encoder { encoder }

    deinit {
        var result = MsgPack.encodeArrayHeader(count)
        for item in items { result.append(item) }
        encoder.data = result
    }
}

// MARK: - Single Value Container

private class MsgPackSingleValueContainer: SingleValueEncodingContainer {
    var codingPath: [CodingKey]
    let encoder: MsgPackEncoderImpl

    init(encoder: MsgPackEncoderImpl, codingPath: [CodingKey]) {
        self.encoder = encoder
        self.codingPath = codingPath
    }

    func encodeNil() throws { encoder.data = Data([0xc0]) }
    func encode(_ value: Bool) throws { encoder.data = Data([value ? 0xc3 : 0xc2]) }
    func encode(_ value: String) throws { encoder.data = MsgPack.encodeString(value) }
    func encode(_ value: Int) throws { encoder.data = MsgPack.encodeInt(Int64(value)) }
    func encode(_ value: Int8) throws { try encode(Int(value)) }
    func encode(_ value: Int16) throws { try encode(Int(value)) }
    func encode(_ value: Int32) throws { try encode(Int(value)) }
    func encode(_ value: Int64) throws { encoder.data = MsgPack.encodeInt(value) }
    func encode(_ value: UInt) throws { encoder.data = MsgPack.encodeUInt(UInt64(value)) }
    func encode(_ value: UInt8) throws { try encode(UInt(value)) }
    func encode(_ value: UInt16) throws { try encode(UInt(value)) }
    func encode(_ value: UInt32) throws { try encode(UInt(value)) }
    func encode(_ value: UInt64) throws { encoder.data = MsgPack.encodeUInt(value) }
    func encode(_ value: Float) throws { try encode(Double(value)) }
    func encode(_ value: Double) throws { encoder.data = MsgPack.encodeDouble(value) }

    func encode<T: Encodable>(_ value: T) throws {
        let sub = MsgPackEncoderImpl()
        try value.encode(to: sub)
        encoder.data = sub.data
    }
}

// MARK: - Primitive Encoding

private enum MsgPack {

    static func encodeString(_ str: String) -> Data {
        let bytes = Array(str.utf8)
        let len = bytes.count
        var result = Data()
        if len < 32 {
            result.append(UInt8(0xa0 | len))
        } else if len < 256 {
            result.append(0xd9)
            result.append(UInt8(len))
        } else if len < 65536 {
            result.append(0xda)
            result.append(UInt8(len >> 8))
            result.append(UInt8(len & 0xff))
        } else {
            result.append(0xdb)
            result.append(contentsOf: withUnsafeBytes(of: UInt32(len).bigEndian) { Array($0) })
        }
        result.append(contentsOf: bytes)
        return result
    }

    static func encodeInt(_ value: Int64) -> Data {
        if value >= 0 { return encodeUInt(UInt64(value)) }
        if value >= -32 { return Data([UInt8(bitPattern: Int8(value))]) }
        if value >= Int64(Int8.min) {
            return Data([0xd0, UInt8(bitPattern: Int8(value))])
        }
        if value >= Int64(Int16.min) {
            var d = Data([0xd1])
            d.append(contentsOf: withUnsafeBytes(of: Int16(value).bigEndian) { Array($0) })
            return d
        }
        if value >= Int64(Int32.min) {
            var d = Data([0xd2])
            d.append(contentsOf: withUnsafeBytes(of: Int32(value).bigEndian) { Array($0) })
            return d
        }
        var d = Data([0xd3])
        d.append(contentsOf: withUnsafeBytes(of: value.bigEndian) { Array($0) })
        return d
    }

    static func encodeUInt(_ value: UInt64) -> Data {
        if value < 128 { return Data([UInt8(value)]) }
        if value <= UInt64(UInt8.max) { return Data([0xcc, UInt8(value)]) }
        if value <= UInt64(UInt16.max) {
            var d = Data([0xcd])
            d.append(contentsOf: withUnsafeBytes(of: UInt16(value).bigEndian) { Array($0) })
            return d
        }
        if value <= UInt64(UInt32.max) {
            var d = Data([0xce])
            d.append(contentsOf: withUnsafeBytes(of: UInt32(value).bigEndian) { Array($0) })
            return d
        }
        var d = Data([0xcf])
        d.append(contentsOf: withUnsafeBytes(of: value.bigEndian) { Array($0) })
        return d
    }

    static func encodeDouble(_ value: Double) -> Data {
        var d = Data([0xcb])
        d.append(contentsOf: withUnsafeBytes(of: value.bitPattern.bigEndian) { Array($0) })
        return d
    }

    static func encodeMapHeader(_ count: Int) -> Data {
        if count < 16 { return Data([UInt8(0x80 | count)]) }
        if count < 65536 {
            var d = Data([0xde])
            d.append(contentsOf: withUnsafeBytes(of: UInt16(count).bigEndian) { Array($0) })
            return d
        }
        var d = Data([0xdf])
        d.append(contentsOf: withUnsafeBytes(of: UInt32(count).bigEndian) { Array($0) })
        return d
    }

    static func encodeArrayHeader(_ count: Int) -> Data {
        if count < 16 { return Data([UInt8(0x90 | count)]) }
        if count < 65536 {
            var d = Data([0xdc])
            d.append(contentsOf: withUnsafeBytes(of: UInt16(count).bigEndian) { Array($0) })
            return d
        }
        var d = Data([0xdd])
        d.append(contentsOf: withUnsafeBytes(of: UInt32(count).bigEndian) { Array($0) })
        return d
    }
}
