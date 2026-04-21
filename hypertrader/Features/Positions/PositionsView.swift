import SwiftUI

struct PositionsView: View {
    @State private var vm = PositionsViewModel()

    /// Read the shared observable so the wallet header re-renders when the user
    /// connects or disconnects (from the Markets `TradeSheet` or from this view).
    private var wcManager: WalletConnectManager { WalletConnectManager.shared }

    var body: some View {
        NavigationStack {
            List {
                walletSection

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

    // MARK: - Wallet Section

    @ViewBuilder
    private var walletSection: some View {
        Section("Wallet") {
            if wcManager.isConnected, let address = wcManager.walletAddress {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(formatShortAddress(address))
                        .font(.body.monospaced())
                    Spacer()
                }

                Button("Disconnect Wallet", role: .destructive) {
                    Task { await wcManager.disconnect() }
                }
            } else {
                Text("No wallet connected")
                    .foregroundStyle(.secondary)
            }
        }
    }

}

#Preview {
    PositionsView()
}
