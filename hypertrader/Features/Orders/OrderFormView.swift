import SwiftUI

/// Order form with Long/Short tabs, Market/Limit + Cross/Isolated dropdowns,
/// size and leverage sliders with text inputs, order info, and a "Place Order" button.
struct OrderFormView: View {
    @Bindable var order: OrderViewModel

    let asset: HLAsset?
    let assetIndex: Int?

    /// Fired after `placeOrder` returns so the parent can refresh position + history.
    let onOrderPlaced: () -> Void

    private var maxLeverage: Double {
        Double(asset?.maxLeverage ?? 50)
    }

    /// Reasonable max size for the slider based on asset price.
    /// Higher-priced assets get a smaller max size.
    private var maxSize: Double {
        guard let asset,
              let mid = HyperliquidWebSocketService.shared.mids[asset.name],
              let price = Double(mid), price > 0 else { return 10 }
        // Target ~$50k notional at max slider position
        return max(1, 50_000 / price)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Market/Limit + Cross/Isolated dropdowns
            HStack {
                Picker("Type", selection: $order.isMarketOrder) {
                    Text("Market").tag(true)
                    Text("Limit").tag(false)
                }
                .pickerStyle(.menu)
                .tint(.primary)

                Spacer()

                Picker("Margin", selection: $order.isIsolated) {
                    Text("Isolated").tag(true)
                    Text("Cross").tag(false)
                }
                .pickerStyle(.menu)
                .tint(.primary)
            }
            .padding(.horizontal)
            .padding(.top, 12)

            // Long / Short tabs
            Picker("", selection: $order.isBuy) {
                Text("Long").tag(true)
                Text("Short").tag(false)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // Price (limit only)
            if !order.isMarketOrder {
                LabeledNumericField(label: "Price", text: $order.priceText)
                    .padding(.horizontal)
            }

            // Size — text input + slider
            VStack(spacing: 6) {
                LabeledNumericField(label: "Size", text: $order.sizeText)
                Slider(value: $order.sizeValue, in: 0...maxSize)
                    .tint(order.isBuy ? .green : .red)
            }
            .padding(.horizontal)

            // Leverage — text input + slider
            VStack(spacing: 6) {
                LabeledNumericField(label: "Leverage", text: $order.leverageText)
                Slider(value: $order.leverage, in: 1...maxLeverage, step: 1)
                    .tint(order.isBuy ? .green : .red)
            }
            .padding(.horizontal)

            // Order info
            orderInfoSection
                .padding(.horizontal)

            // Place Order button
            Button {
                placeOrder()
            } label: {
                Text("Place Order")
            }
            .buttonStyle(PrimaryButtonStyle(
                color: order.isBuy ? .green : .red,
                isLoading: order.isPlacingOrder
            ))
            .disabled(!canPlaceOrder || order.isPlacingOrder)
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

    // MARK: - Order Info

    private var orderInfoSection: some View {
        VStack(spacing: 4) {
            if let value = order.orderValue(asset: asset) {
                MetricRow(label: "Order Value", value: formatDisplayPrice(value))
            }
            if let margin = order.marginRequired(asset: asset) {
                MetricRow(label: "Margin Required", value: formatDisplayPrice(margin))
            }
            if let liq = order.estimatedLiqPrice(asset: asset) {
                MetricRow(label: "Liquidation Price", value: formatDisplayPrice(liq))
            }
        }
    }

    // MARK: - Actions

    private var canPlaceOrder: Bool {
        asset != nil && assetIndex != nil && order.canPlaceOrder(asset: asset)
    }

    private func placeOrder() {
        guard let asset, let assetIndex else { return }
        Task {
            await order.placeOrder(asset: asset, assetIndex: assetIndex)
            onOrderPlaced()
        }
    }
}

private let previewAsset = HLAsset(
    name: "BTC", szDecimals: 5, maxLeverage: 50,
    onlyIsolated: nil, isDelisted: nil
)

#Preview("Empty (no asset)") {
    @Previewable @State var order = OrderViewModel()
    OrderFormView(order: order, asset: nil, assetIndex: nil, onOrderPlaced: {})
}

#Preview("Long — Market") {
    @Previewable @State var order: OrderViewModel = {
        let o = OrderViewModel()
        o.isBuy = true
        o.isMarketOrder = true
        o.sizeText = "0.05"
        o.leverage = 10
        return o
    }()
    OrderFormView(order: order, asset: previewAsset, assetIndex: 0, onOrderPlaced: {})
}

#Preview("Short — Limit") {
    @Previewable @State var order: OrderViewModel = {
        let o = OrderViewModel()
        o.isBuy = false
        o.isMarketOrder = false
        o.sizeText = "1.5"
        o.priceText = "2450.00"
        o.leverage = 20
        return o
    }()
    OrderFormView(order: order, asset: previewAsset, assetIndex: 0, onOrderPlaced: {})
}

#Preview("High Leverage") {
    @Previewable @State var order: OrderViewModel = {
        let o = OrderViewModel()
        o.isBuy = true
        o.sizeText = "0.01"
        o.leverage = 50
        o.isIsolated = true
        return o
    }()
    OrderFormView(order: order, asset: previewAsset, assetIndex: 0, onOrderPlaced: {})
}

#Preview("Cross Margin — Short") {
    @Previewable @State var order: OrderViewModel = {
        let o = OrderViewModel()
        o.isBuy = false
        o.isIsolated = false
        o.sizeText = "0.1"
        o.leverage = 5
        return o
    }()
    OrderFormView(order: order, asset: previewAsset, assetIndex: 0, onOrderPlaced: {})
}
