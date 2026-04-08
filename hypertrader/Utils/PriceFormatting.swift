import Foundation

/// Remove trailing zeros from a decimal string (Hyperliquid wire format requirement).
func formatPrice(_ value: String) -> String {
    guard let decimal = Decimal(string: value) else { return value }
    return NSDecimalNumber(decimal: decimal).stringValue
}

/// Format a price for display, matching Hyperliquid UI precision.
/// >= 10000 → integer, >= 100 → 2 decimals, >= 1 → 4 decimals, < 1 → 6 decimals
func formatDisplayPrice(_ price: Double) -> String {
    if price >= 10000 { return String(format: "%.0f", price) }
    if price >= 100 { return String(format: "%.2f", price) }
    if price >= 1 { return String(format: "%.4f", price) }
    return String(format: "%.6f", price)
}

/// Format a price string for display (parses then formats).
func formatDisplayPrice(_ price: String) -> String {
    guard let d = Double(price) else { return price }
    return formatDisplayPrice(d)
}
