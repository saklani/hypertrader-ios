import SwiftUI

struct TradingView: View {
    @State private var vm = TradingViewModel()

    var body: some View {
        NavigationStack {
            Form {
                // Asset selector + price
                Section("Market") {
                    NavigationLink {
                        AssetPickerView(
                            assets: vm.filteredAssets,
                            searchText: $vm.searchText,
                            selectedAsset: $vm.selectedAsset
                        )
                    } label: {
                        HStack {
                            Text("Asset")
                            Spacer()
                            Text(vm.selectedAsset?.name ?? "Select")
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Text("Mid Price")
                        Spacer()
                        Text(vm.currentMidPrice)
                            .font(.body.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }

                // Order form
                Section("Order") {
                    // Buy / Sell
                    Picker("Side", selection: $vm.isBuy) {
                        Text("Buy").tag(true)
                        Text("Sell").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

                    // Market / Limit
                    Picker("Type", selection: $vm.isMarketOrder) {
                        Text("Market").tag(true)
                        Text("Limit").tag(false)
                    }
                    .pickerStyle(.segmented)

                    // Size
                    HStack {
                        Text("Size")
                        TextField("0.00", text: $vm.sizeText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.body.monospaced())
                    }

                    // Price (limit only)
                    if !vm.isMarketOrder {
                        HStack {
                            Text("Price")
                            TextField("0.00", text: $vm.priceText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(.body.monospaced())
                        }
                    }
                }

                // Place order button
                Section {
                    Button {
                        Task { await vm.placeOrder() }
                    } label: {
                        HStack {
                            Spacer()
                            if vm.isPlacingOrder {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(vm.isBuy ? "Buy" : "Sell")
                                .font(.headline)
                            if let asset = vm.selectedAsset {
                                Text(asset.name)
                                    .font(.headline)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(vm.isBuy ? Color.green : Color.red)
                    .foregroundStyle(.white)
                    .disabled(!vm.canPlaceOrder || vm.isPlacingOrder)
                }

                // Result / Error
                if let result = vm.orderResult {
                    Section {
                        Label(result, systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                    }
                }

                if let error = vm.orderError {
                    Section {
                        Label(error, systemImage: "xmark.circle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Trade")
            .task {
                await vm.loadMarketData()
            }
            .refreshable {
                await vm.loadMarketData()
            }
        }
    }
}

#Preview {
    TradingView()
}
