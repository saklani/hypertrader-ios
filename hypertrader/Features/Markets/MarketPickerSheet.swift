import SwiftUI

/// Modal searchable list of assets. Owns its own search text as local `@State`
/// so a fresh search starts each time the sheet opens.
struct MarketPickerSheet: View {
    let assets: [AssetWithVolume]
    let midPrices: [String: String]
    let onSelect: (HLAsset) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List(filteredAssets) { item in
                MarketRowView(
                    coin: item.asset.name,
                    price: Double(midPrices[item.asset.name] ?? ""),
                    change24h: change24h(for: item),
                    volume: item.dayNtlVlm
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelect(item.asset)
                    dismiss()
                }
            }
            .listStyle(.plain)
            .navigationTitle("Select Asset")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search coins...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var filteredAssets: [AssetWithVolume] {
        if searchText.isEmpty { return assets }
        return assets.filter {
            $0.asset.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func change24h(for item: AssetWithVolume) -> Double? {
        guard let currentStr = midPrices[item.asset.name],
              let current = Double(currentStr),
              item.prevDayPx > 0 else { return nil }
        return (current - item.prevDayPx) / item.prevDayPx * 100
    }
}

#Preview {
    MarketPickerSheet(
        assets: [
            AssetWithVolume(asset: HLAsset(name: "BTC", szDecimals: 5, maxLeverage: 50, onlyIsolated: nil, isDelisted: nil), dayNtlVlm: 1_250_000_000, prevDayPx: 93000),
            AssetWithVolume(asset: HLAsset(name: "ETH", szDecimals: 4, maxLeverage: 50, onlyIsolated: nil, isDelisted: nil), dayNtlVlm: 890_000_000, prevDayPx: 3150),
            AssetWithVolume(asset: HLAsset(name: "SOL", szDecimals: 2, maxLeverage: 20, onlyIsolated: nil, isDelisted: nil), dayNtlVlm: 320_000_000, prevDayPx: 135),
        ],
        midPrices: ["BTC": "95123.50", "ETH": "3200.10", "SOL": "142.30"],
        onSelect: { _ in }
    )
}
