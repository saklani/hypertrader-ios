import SwiftUI

struct AssetPickerView: View {
    let assets: [AssetWithVolume]
    @Binding var searchText: String
    @Binding var selectedAsset: HLAsset?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(assets) { item in
            Button {
                selectedAsset = item.asset
                dismiss()
            } label: {
                HStack {
                    Text(item.asset.name)
                        .font(.body.bold())
                    Spacer()
                    Text(formatVolume(item.dayNtlVlm))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    if item.asset == selectedAsset {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .navigationTitle("Select Asset")
        .searchable(text: $searchText, prompt: "Search coins...")
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1_000_000_000 {
            return String(format: "$%.1fB", volume / 1_000_000_000)
        } else if volume >= 1_000_000 {
            return String(format: "$%.1fM", volume / 1_000_000)
        } else if volume >= 1_000 {
            return String(format: "$%.0fK", volume / 1_000)
        }
        return String(format: "$%.0f", volume)
    }
}

#Preview {
    NavigationStack {
        AssetPickerView(
            assets: [
                AssetWithVolume(asset: HLAsset(name: "BTC", szDecimals: 5), dayNtlVlm: 1_250_000_000, prevDayPx: 93000),
                AssetWithVolume(asset: HLAsset(name: "ETH", szDecimals: 4), dayNtlVlm: 890_000_000, prevDayPx: 3150),
                AssetWithVolume(asset: HLAsset(name: "SOL", szDecimals: 2), dayNtlVlm: 320_000_000, prevDayPx: 135),
                AssetWithVolume(asset: HLAsset(name: "DOGE", szDecimals: 0), dayNtlVlm: 45_000_000, prevDayPx: 0.18),
                AssetWithVolume(asset: HLAsset(name: "HYPE", szDecimals: 2), dayNtlVlm: 12_500_000, prevDayPx: 14.10),
            ],
            searchText: .constant(""),
            selectedAsset: .constant(HLAsset(name: "ETH", szDecimals: 4))
        )
    }
}
