import SwiftUI

/// Buy/Sell order form for the currently selected asset.
/// Assumes the wallet is connected + agent is approved — `MarketView` gates
/// this view behind `ConnectWalletView` when `isWalletReady == false`.
///
/// Owns its own `OrderViewModel` internally. The parent only passes the
/// currently selected asset (+ its index in the universe) and a callback
/// to invoke after a successful order so position/history can refresh.
struct OrderFormView: View {
    let asset: HLAsset?
    let assetIndex: Int?

    /// Fired after `placeOrder` returns, regardless of success/failure, so
    /// the parent can bump its reload counter and refresh position + history.
    let onOrderPlaced: () -> Void

    @State private var order = OrderViewModel()

    var body: some View {
        VStack(spacing: 12) {
            // Order type dropdown
            HStack {
                Text("Order Type")
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("Type", selection: $order.isMarketOrder) {
                    Text("Market").tag(true)
                    Text("Limit").tag(false)
                }
                .pickerStyle(.menu)
                .tint(.primary)
            }
            .padding(.horizontal)
            .padding(.top, 12)

            // Size
            LabeledNumericField(label: "Size", text: $order.sizeText)
                .padding(.horizontal)

            // Price (limit only)
            if !order.isMarketOrder {
                LabeledNumericField(label: "Price", text: $order.priceText)
                    .padding(.horizontal)
            }

            // Buy / Sell buttons
            HStack(spacing: 12) {
                Button {
                    placeOrder(isBuy: true)
                } label: {
                    Text("Buy")
                }
                .buttonStyle(PrimaryButtonStyle(color: .green, isLoading: order.isPlacingOrder && order.isBuy))
                .disabled(!canPlaceOrder || order.isPlacingOrder)

                Button {
                    placeOrder(isBuy: false)
                } label: {
                    Text("Sell")
                }
                .buttonStyle(PrimaryButtonStyle(color: .red, isLoading: order.isPlacingOrder && !order.isBuy))
                .disabled(!canPlaceOrder || order.isPlacingOrder)
            }
            .padding(.horizontal)
            .padding(.bottom, 4)

            // Status
            if let result = order.orderResult {
                StatusMessage(result, isError: false)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
            if let error = order.orderError {
                StatusMessage(error, isError: true)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Actions

    private var canPlaceOrder: Bool {
        asset != nil && assetIndex != nil && order.canPlaceOrder(asset: asset)
    }

    private func placeOrder(isBuy: Bool) {
        order.isBuy = isBuy
        guard let asset, let assetIndex else { return }
        Task {
            await order.placeOrder(asset: asset, assetIndex: assetIndex)
            onOrderPlaced()
        }
    }
}

#Preview("Disabled (no asset)") {
    OrderFormView(
        asset: nil,
        assetIndex: nil,
        onOrderPlaced: {}
    )
}
