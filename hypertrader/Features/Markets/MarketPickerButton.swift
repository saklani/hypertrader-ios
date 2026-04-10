import SwiftUI

/// Small tappable header button that shows the currently selected asset name and a chevron.
/// Opens `MarketPickerSheet` when tapped. Knows nothing about the asset list or the price.
struct MarketPickerButton: View {
    let assetName: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Text(assetName)
                    .font(.title2.bold())
                Image(systemName: "chevron.down")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(MarketPickerButtonStyle())
    }
}

/// Shows a subtle highlight when pressed.
private struct MarketPickerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(configuration.isPressed ? Color.accentColor.opacity(0.1) : Color(.systemGray6).opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
    }
}

#Preview {
    MarketPickerButton(assetName: "BTC", onTap: {})
        .padding()
}
