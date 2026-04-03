import SwiftUI

/// Tappable header (BTC/USDC ▼ + price) that opens a searchable picker sheet.
struct MarketPicker: View {
    let assetName: String
    let price: String
    let assets: [AssetWithVolume]
    let midPrices: [String: String]
    @Binding var searchText: String
    let onSelect: (HLAsset) -> Void

    @State private var showPicker = false

    var body: some View {
        HStack {
            Button {
                showPicker = true
            } label: {
                HStack(spacing: 4) {
                    Text(assetName)
                        .font(.title2.bold())
                    Image(systemName: "chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(MarketPickerButtonStyle())

            Spacer()

            Text(price)
                .font(.title3.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .sheet(isPresented: $showPicker) {
            pickerSheet
        }
    }

    // MARK: - Picker Sheet

    private var pickerSheet: some View {
        NavigationStack {
            List(filteredAssets) { item in
                Button {
                    onSelect(item.asset)
                    showPicker = false
                } label: {
                    MarketRowView(
                        coin: item.asset.name,
                        price: Double(midPrices[item.asset.name] ?? ""),
                        change24h: change24h(for: item),
                        volume: item.dayNtlVlm
                    )
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .navigationTitle("Select Asset")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search coins...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showPicker = false }
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

/// Shows a subtle highlight when pressed.
private struct MarketPickerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(configuration.isPressed ? Color.accentColor.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Previews

#Preview {
    MarketPicker(
        assetName: "BTC",
        price: "$95,123.50",
        assets: [
            AssetWithVolume(asset: HLAsset(name: "BTC", szDecimals: 5, maxLeverage: 50, onlyIsolated: nil, isDelisted: nil), dayNtlVlm: 1_250_000_000, prevDayPx: 93000),
            AssetWithVolume(asset: HLAsset(name: "ETH", szDecimals: 4, maxLeverage: 50, onlyIsolated: nil, isDelisted: nil), dayNtlVlm: 890_000_000, prevDayPx: 3150),
            AssetWithVolume(asset: HLAsset(name: "SOL", szDecimals: 2, maxLeverage: 20, onlyIsolated: nil, isDelisted: nil), dayNtlVlm: 320_000_000, prevDayPx: 135),
        ],
        midPrices: ["BTC": "95123.50", "ETH": "3200.10", "SOL": "142.30"],
        searchText: .constant(""),
        onSelect: { _ in }
    )
}
