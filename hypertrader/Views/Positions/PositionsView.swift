import SwiftUI

struct PositionsView: View {
    @State private var vm = PositionsViewModel()

    var body: some View {
        NavigationStack {
            List {
                // Account summary
                Section("Account") {
                    MetricRow(label: "Account Value", value: vm.accountValue)
                    MetricRow(label: "Margin Used", value: vm.totalMarginUsed)
                }

                // Positions
                Section("Open Positions") {
                    if vm.positions.isEmpty && !vm.isLoading {
                        Text("No open positions")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(vm.positions) { assetPosition in
                        PositionRowView(
                            position: assetPosition,
                            midPrice: vm.midPrices[assetPosition.position.coin],
                            isClosing: vm.closingCoin == assetPosition.position.coin
                        ) {
                            Task { await vm.closePosition(assetPosition) }
                        }
                    }
                }

                if let error = vm.error {
                    Section {
                        StatusMessage(error, isError: true)
                    }
                }
            }
            .navigationTitle("Positions")
            .task {
                await vm.loadPositions()
                vm.startAutoRefresh()
            }
            .onDisappear {
                vm.stopAutoRefresh()
            }
            .refreshable {
                await vm.loadPositions()
            }
            .overlay {
                if vm.isLoading && vm.positions.isEmpty {
                    ProgressView("Loading positions...")
                }
            }
        }
    }
}

#Preview {
    PositionsView()
}
