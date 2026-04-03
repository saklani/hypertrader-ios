import SwiftUI

/// Trading UI below the chart: order form, active position, trade history, or connect-wallet prompt.
struct OrderFormView: View {
    // Wallet state
    let isWalletReady: Bool

    // Order form bindings
    @Binding var isMarketOrder: Bool
    @Binding var sizeText: String
    @Binding var priceText: String

    // Order state
    let isPlacingOrder: Bool
    let canPlaceOrder: Bool
    let isBuy: Bool
    let orderResult: String?
    let orderError: String?

    // Position
    let activePosition: HLAssetPosition?
    let midPrices: [String: String]
    let isClosingPosition: Bool
    let fills: [HLFill]

    // Actions
    let onBuy: () -> Void
    let onSell: () -> Void
    let onClosePosition: () -> Void

    var body: some View {
        if isWalletReady {
            VStack(spacing: 0) {
                orderSection
                positionSection
                historySection
            }
        } else {
            connectWalletPrompt
        }
    }

    // MARK: - Order Section

    private var orderSection: some View {
        VStack(spacing: 12) {
            // Order type dropdown
            HStack {
                Text("Order Type")
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("Type", selection: $isMarketOrder) {
                    Text("Market").tag(true)
                    Text("Limit").tag(false)
                }
                .pickerStyle(.menu)
                .tint(.primary)
            }
            .padding(.horizontal)
            .padding(.top, 12)

            // Size
            LabeledNumericField(label: "Size", text: $sizeText)
                .padding(.horizontal)

            // Price (limit only)
            if !isMarketOrder {
                LabeledNumericField(label: "Price", text: $priceText)
                    .padding(.horizontal)
            }

            // Buy / Sell buttons
            HStack(spacing: 12) {
                Button(action: onBuy) {
                    Text("Buy")
                }
                .buttonStyle(PrimaryButtonStyle(color: .green, isLoading: isPlacingOrder && isBuy))
                .disabled(!canPlaceOrder || isPlacingOrder)

                Button(action: onSell) {
                    Text("Sell")
                }
                .buttonStyle(PrimaryButtonStyle(color: .red, isLoading: isPlacingOrder && !isBuy))
                .disabled(!canPlaceOrder || isPlacingOrder)
            }
            .padding(.horizontal)
            .padding(.bottom, 4)

            // Status
            if let result = orderResult {
                StatusMessage(result, isError: false)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
            if let error = orderError {
                StatusMessage(error, isError: true)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Position Section

    private var positionSection: some View {
        Group {
            if let position = activePosition {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    Text("Active Position")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    PositionRowView(
                        position: position,
                        midPrice: midPrices[position.position.coin],
                        isClosing: isClosingPosition,
                        onClose: onClosePosition
                    )
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider().padding(.top, 4)
            Text("Trade History")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 8)

            if fills.isEmpty {
                Text("No trades yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
            } else {
                ForEach(fills.prefix(20)) { fill in
                    TradeHistoryRow(fill: fill)
                        .padding(.horizontal)
                }
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: - Connect Wallet

    private var connectWalletPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "wallet.bifold")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
                .padding(.top, 24)
            Text("Connect a wallet to trade")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Go to Settings to connect your wallet")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - Previews

private func previewPosition() -> HLAssetPosition {
    HLAssetPosition(
        type: "oneWay",
        position: HLPosition(
            coin: "BTC", szi: "0.0500", entryPx: "94500.00",
            positionValue: "4725.00", unrealizedPnl: "31.18",
            returnOnEquity: "0.066", liquidationPx: "88000.00",
            marginUsed: "472.50", leverage: HLLeverage(type: "cross", value: 10, rawUsd: nil),
            maxLeverage: nil, cumFunding: nil
        )
    )
}

private func previewFills() -> [HLFill] {
    let now = UInt64(Date().timeIntervalSince1970 * 1000)
    return [
        HLFill(coin: "BTC", side: "B", px: "94500.00", sz: "0.0500", time: now - 3600000, fee: "0.50", oid: 1, tid: nil, closedPnl: nil, hash: nil, crossed: nil, dir: nil, startPosition: nil, feeToken: nil, builderFee: nil),
        HLFill(coin: "BTC", side: "A", px: "93800.00", sz: "0.0200", time: now - 7200000, fee: "0.20", oid: 2, tid: nil, closedPnl: nil, hash: nil, crossed: nil, dir: nil, startPosition: nil, feeToken: nil, builderFee: nil),
        HLFill(coin: "BTC", side: "B", px: "93200.00", sz: "0.0200", time: now - 10800000, fee: "0.20", oid: 3, tid: nil, closedPnl: nil, hash: nil, crossed: nil, dir: nil, startPosition: nil, feeToken: nil, builderFee: nil),
    ]
}

#Preview("No Wallet Connected") {
    OrderFormView(
        isWalletReady: false,
        isMarketOrder: .constant(true),
        sizeText: .constant(""),
        priceText: .constant(""),
        isPlacingOrder: false,
        canPlaceOrder: false,
        isBuy: true,
        orderResult: nil,
        orderError: nil,
        activePosition: nil,
        midPrices: [:],
        isClosingPosition: false,
        fills: [],
        onBuy: {},
        onSell: {},
        onClosePosition: {}
    )
}

#Preview("Wallet Connected") {
    ScrollView {
        OrderFormView(
            isWalletReady: true,
            isMarketOrder: .constant(true),
            sizeText: .constant("0.05"),
            priceText: .constant(""),
            isPlacingOrder: false,
            canPlaceOrder: true,
            isBuy: true,
            orderResult: nil,
            orderError: nil,
            activePosition: previewPosition(),
            midPrices: ["BTC": "95123.50"],
            isClosingPosition: false,
            fills: previewFills(),
            onBuy: {},
            onSell: {},
            onClosePosition: {}
        )
    }
}
