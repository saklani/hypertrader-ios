import SwiftUI

/// Displays a live mid price for an asset.
/// Purely presentational — takes a pre-formatted string and renders it with
/// monospaced digits so the trailing digits don't jitter horizontally on each tick.
struct LivePriceLabel: View {
    let price: String

    var body: some View {
        Text(price)
            .font(.title3.monospaced())
            .foregroundStyle(.secondary)
    }
}

#Preview {
    VStack(spacing: 12) {
        LivePriceLabel(price: "95123.50")
        LivePriceLabel(price: "3200.10")
        LivePriceLabel(price: "--")
    }
    .padding()
}
