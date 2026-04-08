import Foundation

/// Keccak256 hash function (Ethereum's hash, NOT NIST SHA-3-256).
/// Pure Swift implementation — no external dependencies.
nonisolated enum Keccak {

    /// Compute Keccak256 hash of raw bytes
    static func keccak256(_ input: [UInt8]) -> [UInt8] {
        let rate = 136 // (1600 - 256*2) / 8 = 136 bytes
        var state = [UInt64](repeating: 0, count: 25)

        // Pad: append 0x01, zero-fill, set last byte high bit
        var padded = input
        padded.append(0x01)
        while padded.count % rate != 0 {
            padded.append(0x00)
        }
        padded[padded.count - 1] |= 0x80

        // Absorb
        for offset in stride(from: 0, to: padded.count, by: rate) {
            for i in 0..<(rate / 8) {
                let j = offset + i * 8
                let lane = UInt64(padded[j])
                    | UInt64(padded[j+1]) << 8
                    | UInt64(padded[j+2]) << 16
                    | UInt64(padded[j+3]) << 24
                    | UInt64(padded[j+4]) << 32
                    | UInt64(padded[j+5]) << 40
                    | UInt64(padded[j+6]) << 48
                    | UInt64(padded[j+7]) << 56
                state[i] ^= lane
            }
            keccakF1600(&state)
        }

        // Squeeze (256 bits = 32 bytes, fits in one block)
        var output = [UInt8](repeating: 0, count: 32)
        for i in 0..<4 {
            let lane = state[i]
            for b in 0..<8 {
                output[i * 8 + b] = UInt8((lane >> (b * 8)) & 0xFF)
            }
        }
        return output
    }

    /// Compute Keccak256 hash of Data
    static func keccak256(_ data: Data) -> Data {
        Data(keccak256(Array(data)))
    }

    // MARK: - Keccak-f[1600] Permutation (24 rounds)

    private static func keccakF1600(_ state: inout [UInt64]) {
        for round in 0..<24 {
            // θ (theta)
            var c = [UInt64](repeating: 0, count: 5)
            for x in 0..<5 {
                c[x] = state[x] ^ state[x+5] ^ state[x+10] ^ state[x+15] ^ state[x+20]
            }
            for x in 0..<5 {
                let d = c[(x+4) % 5] ^ rotl(c[(x+1) % 5], 1)
                for y in stride(from: 0, to: 25, by: 5) {
                    state[y + x] ^= d
                }
            }

            // ρ (rho) + π (pi)
            var temp = [UInt64](repeating: 0, count: 25)
            temp[0] = state[0]
            for i in 0..<24 {
                temp[piLane[i]] = rotl(state[piSource[i]], rhoOffset[i])
            }

            // χ (chi)
            for y in stride(from: 0, to: 25, by: 5) {
                let t0 = temp[y], t1 = temp[y+1], t2 = temp[y+2], t3 = temp[y+3], t4 = temp[y+4]
                state[y]   = t0 ^ (~t1 & t2)
                state[y+1] = t1 ^ (~t2 & t3)
                state[y+2] = t2 ^ (~t3 & t4)
                state[y+3] = t3 ^ (~t4 & t0)
                state[y+4] = t4 ^ (~t0 & t1)
            }

            // ι (iota)
            state[0] ^= roundConstants[round]
        }
    }

    private static func rotl(_ x: UInt64, _ n: Int) -> UInt64 {
        (x << n) | (x >> (64 - n))
    }

    // MARK: - Constants

    // π step: destination indices for lanes 1-24
    private static let piLane: [Int] = [
        10, 7, 11, 17, 18, 3, 5, 16, 8, 21,
        24, 4, 15, 23, 19, 13, 12, 2, 20, 14,
        22, 9, 6, 1
    ]

    // π step: source indices for lanes 1-24
    private static let piSource: [Int] = [
        1, 10, 7, 11, 17, 18, 3, 5, 16, 8,
        21, 24, 4, 15, 23, 19, 13, 12, 2, 20,
        14, 22, 9, 6
    ]

    // ρ step: rotation offsets for lanes 1-24
    private static let rhoOffset: [Int] = [
        1, 3, 6, 10, 15, 21, 28, 36, 45, 55,
        2, 14, 27, 41, 56, 8, 25, 43, 62, 18,
        39, 61, 20, 44
    ]

    // ι step: round constants
    private static let roundConstants: [UInt64] = [
        0x0000000000000001, 0x0000000000008082, 0x800000000000808A, 0x8000000080008000,
        0x000000000000808B, 0x0000000080000001, 0x8000000080008081, 0x8000000000008009,
        0x000000000000008A, 0x0000000000000088, 0x0000000080008009, 0x000000008000000A,
        0x000000008000808B, 0x800000000000008B, 0x8000000000008089, 0x8000000000008003,
        0x8000000000008002, 0x8000000000000080, 0x000000000000800A, 0x800000008000000A,
        0x8000000080008081, 0x8000000000008080, 0x0000000080000001, 0x8000000080008008
    ]
}
