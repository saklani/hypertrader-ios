import Foundation

/// Shortens an Ethereum address for display: `0x73bb…4B03`.
/// Returns the input unchanged if it's already short enough.
func formatShortAddress(_ address: String) -> String {
    guard address.count > 10 else { return address }
    return "\(address.prefix(6))…\(address.suffix(4))"
}
